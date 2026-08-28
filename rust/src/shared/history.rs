use {
    crate::calculator::error::CalcError,
    serde::{Deserialize, Serialize},
    std::{
        fs,
        sync::Mutex,
        time::{SystemTime, UNIX_EPOCH},
    },
};

/// Represents a single calculation in the application history.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: String,
    pub category: String,
    pub timestamp: i64,
    pub preview: String,
    pub snapshot: String,
    pub version: u32,
}

pub struct HistoryManager {
    history: Mutex<Vec<HistoryEntry>>,
}

impl Default for HistoryManager {
    fn default() -> Self {
        Self::new()
    }
}

impl HistoryManager {
    pub const fn new() -> Self {
        Self {
            history: Mutex::new(Vec::new()),
        }
    }

    pub fn add(&self, category: String, preview: String, snapshot: String) {
        if let Ok(mut history) = self.history.lock() {
            if let Some(last) = history.last()
                && last.category == category
                && last.preview == preview
            {
                return; // Avoid duplicate consecutive history entries
            }

            let timestamp = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64;

            // Generate a simple unique ID using timestamp + a random-like counter
            // Since this is local, timestamp-based is fine. We append length just to avoid collisions in the exact same ms.
            let id = format!("{}_{}", timestamp, history.len());

            history.push(HistoryEntry {
                id,
                category,
                timestamp,
                preview,
                snapshot,
                version: 1,
            });
        }
    }

    pub fn get_all(&self) -> Vec<HistoryEntry> {
        if let Ok(history) = self.history.lock() {
            history.clone()
        } else {
            Vec::new()
        }
    }

    pub fn get_by_category(&self, category: &str) -> Vec<HistoryEntry> {
        if let Ok(history) = self.history.lock() {
            history
                .iter()
                .filter(|e| e.category == category)
                .cloned()
                .collect()
        } else {
            Vec::new()
        }
    }

    pub fn clear_all(&self) {
        if let Ok(mut history) = self.history.lock() {
            history.clear();
        }
    }

    pub fn clear_category(&self, category: &str) {
        if let Ok(mut history) = self.history.lock() {
            history.retain(|e| e.category != category);
        }
    }

    pub fn delete(&self, id: &str) {
        if let Ok(mut history) = self.history.lock() {
            history.retain(|e| e.id != id);
        }
    }

    pub fn save(&self, path: &str) -> Result<(), CalcError> {
        let history = self.get_all();
        let json = serde_json::to_string(&history)
            .map_err(|e| CalcError::IoError(format!("Serialization error: {}", e)))?;
        fs::write(path, json)
            .map_err(|e| CalcError::IoError(format!("File write error: {}", e)))?;
        Ok(())
    }

    pub fn load(&self, path: &str) -> Result<(), CalcError> {
        if !std::path::Path::new(path).exists() {
            return Ok(());
        }
        let json = fs::read_to_string(path)
            .map_err(|e| CalcError::IoError(format!("File read error: {}", e)))?;

        // Attempt to deserialize, ignoring failure to allow clean wipe on bad schema
        if let Ok(loaded_history) = serde_json::from_str::<Vec<HistoryEntry>>(&json)
            && let Ok(mut history) = self.history.lock()
        {
            *history = loaded_history;
        }
        Ok(())
    }
}

// Global instance for all calculators
pub static APP_HISTORY: HistoryManager = HistoryManager::new();
