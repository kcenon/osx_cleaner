//! Safety level definitions
//!
//! Defines the 4-level safety classification system for cleanup operations.

use std::fmt;

/// Safety levels for path classification
///
/// Higher numbers indicate more danger - DANGER paths should never be deleted.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[repr(C)]
pub enum SafetyLevel {
    /// Safe to delete immediately, auto-regenerates (e.g., browser cache, Trash)
    Safe = 1,
    /// Deletable but requires rebuild time (e.g., user caches, old logs)
    Caution = 2,
    /// Deletable but requires re-download (e.g., iOS Device Support, Docker images)
    Warning = 3,
    /// Never delete - system damage risk (e.g., /System/*, Keychains)
    Danger = 4,
}

impl SafetyLevel {
    /// Returns true if deletion is allowed at this level
    pub fn is_deletable(&self) -> bool {
        !matches!(self, SafetyLevel::Danger)
    }

    /// Returns true if user confirmation is required before deletion
    pub fn requires_confirmation(&self) -> bool {
        matches!(self, SafetyLevel::Warning | SafetyLevel::Danger)
    }

    /// Returns the display indicator for this safety level
    pub fn indicator(&self) -> &'static str {
        match self {
            SafetyLevel::Safe => "\u{2705}",            // Green checkmark
            SafetyLevel::Caution => "\u{26A0}",         // Warning sign
            SafetyLevel::Warning => "\u{26A0}\u{26A0}", // Double warning
            SafetyLevel::Danger => "\u{274C}",          // Red X
        }
    }

    /// Returns a human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            SafetyLevel::Safe => "Safe to delete, auto-regenerates",
            SafetyLevel::Caution => "Deletable but requires rebuild time",
            SafetyLevel::Warning => "Deletable but requires re-download",
            SafetyLevel::Danger => "Never delete - system damage risk",
        }
    }
}

impl fmt::Display for SafetyLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            SafetyLevel::Safe => "SAFE",
            SafetyLevel::Caution => "CAUTION",
            SafetyLevel::Warning => "WARNING",
            SafetyLevel::Danger => "DANGER",
        };
        write!(f, "{}", name)
    }
}

impl From<u8> for SafetyLevel {
    fn from(value: u8) -> Self {
        match value {
            1 => SafetyLevel::Safe,
            2 => SafetyLevel::Caution,
            3 => SafetyLevel::Warning,
            _ => SafetyLevel::Danger,
        }
    }
}

impl From<SafetyLevel> for u8 {
    fn from(level: SafetyLevel) -> Self {
        level as u8
    }
}

/// Cleanup levels that determine which safety levels are included
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(C)]
pub enum CleanupLevel {
    /// Level 1: Light - Safe only (browser cache, Trash, old downloads)
    Light = 1,
    /// Level 2: Normal - Light + Caution (user caches, old logs)
    Normal = 2,
    /// Level 3: Deep - Normal + Warning (developer caches)
    Deep = 3,
    /// Level 4: System - Deep + restricted system caches (requires root)
    System = 4,
}

impl CleanupLevel {
    /// Returns the maximum SafetyLevel that can be deleted at this cleanup level
    pub fn max_deletable_safety(&self) -> SafetyLevel {
        match self {
            CleanupLevel::Light => SafetyLevel::Safe,
            CleanupLevel::Normal => SafetyLevel::Caution,
            CleanupLevel::Deep => SafetyLevel::Warning,
            CleanupLevel::System => SafetyLevel::Warning, // Never delete Danger
        }
    }

    /// Returns true if the given safety level can be deleted at this cleanup level
    pub fn can_delete(&self, safety: SafetyLevel) -> bool {
        if safety == SafetyLevel::Danger {
            return false;
        }
        safety <= self.max_deletable_safety()
    }
}

impl From<u8> for CleanupLevel {
    fn from(value: u8) -> Self {
        match value {
            1 => CleanupLevel::Light,
            2 => CleanupLevel::Normal,
            3 => CleanupLevel::Deep,
            _ => CleanupLevel::System,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_safety_level_ordering() {
        assert!(SafetyLevel::Safe < SafetyLevel::Caution);
        assert!(SafetyLevel::Caution < SafetyLevel::Warning);
        assert!(SafetyLevel::Warning < SafetyLevel::Danger);
    }

    #[test]
    fn test_safety_level_deletable() {
        assert!(SafetyLevel::Safe.is_deletable());
        assert!(SafetyLevel::Caution.is_deletable());
        assert!(SafetyLevel::Warning.is_deletable());
        assert!(!SafetyLevel::Danger.is_deletable());
    }

    #[test]
    fn test_safety_level_confirmation() {
        assert!(!SafetyLevel::Safe.requires_confirmation());
        assert!(!SafetyLevel::Caution.requires_confirmation());
        assert!(SafetyLevel::Warning.requires_confirmation());
        assert!(SafetyLevel::Danger.requires_confirmation());
    }

    #[test]
    fn test_cleanup_level_can_delete() {
        // Light only deletes Safe
        assert!(CleanupLevel::Light.can_delete(SafetyLevel::Safe));
        assert!(!CleanupLevel::Light.can_delete(SafetyLevel::Caution));

        // Normal deletes Safe and Caution
        assert!(CleanupLevel::Normal.can_delete(SafetyLevel::Safe));
        assert!(CleanupLevel::Normal.can_delete(SafetyLevel::Caution));
        assert!(!CleanupLevel::Normal.can_delete(SafetyLevel::Warning));

        // Deep deletes up to Warning
        assert!(CleanupLevel::Deep.can_delete(SafetyLevel::Warning));
        assert!(!CleanupLevel::Deep.can_delete(SafetyLevel::Danger));

        // System never deletes Danger
        assert!(!CleanupLevel::System.can_delete(SafetyLevel::Danger));
    }

    #[test]
    fn test_from_u8() {
        assert_eq!(SafetyLevel::from(1), SafetyLevel::Safe);
        assert_eq!(SafetyLevel::from(2), SafetyLevel::Caution);
        assert_eq!(SafetyLevel::from(3), SafetyLevel::Warning);
        assert_eq!(SafetyLevel::from(4), SafetyLevel::Danger);
        assert_eq!(SafetyLevel::from(99), SafetyLevel::Danger);
    }
}
