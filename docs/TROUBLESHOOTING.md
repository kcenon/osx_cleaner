# Troubleshooting Guide

> **Version**: 1.0.0
> **Last Updated**: 2026-02-02
> **Purpose**: Comprehensive troubleshooting guide for OSX Cleaner

## Table of Contents

1. [Common Issues](#common-issues)
2. [Error Recovery Scenarios](#error-recovery-scenarios)
3. [Performance Issues](#performance-issues)
4. [Network Issues](#network-issues)
5. [File System Issues](#file-system-issues)
6. [Build and Installation](#build-and-installation)
7. [Diagnostic Tools](#diagnostic-tools)

## Common Issues

### Rust Core Initialization Failure

**Symptoms**:
- "Rust core unavailable, using Swift fallback" warning
- Slower performance than expected
- `isFallbackMode = true` in logs

**Causes**:
1. Rust dylib not found or incompatible
2. Rust version mismatch
3. System security restrictions

**Resolution**:

```bash
# 1. Verify Rust dylib exists
ls -la rust-core/target/release/libosx_core.dylib

# 2. Check Rust version
rustc --version
# Required: >= 1.70.0

# 3. Rebuild Rust core
cd rust-core
cargo clean
cargo build --release

# 4. Verify build succeeded
file target/release/libosx_core.dylib
# Should output: Mach-O 64-bit dynamically linked shared library
```

**Recovery Behavior**:
- System automatically retries initialization 3 times
- Falls back to Swift-only mode after all retries fail
- Application continues to function (slower)

### Application Crashes on Startup

**Symptoms**:
- App terminates immediately on launch
- Crash log shows FFI-related error

**Causes**:
1. Corrupt Rust dylib
2. Missing dependencies
3. Incompatible system version

**Resolution**:

```bash
# 1. Check crash logs
log show --predicate 'process == "osxcleaner"' --last 5m

# 2. Verify system requirements
sw_vers
# Required: macOS 12.0 or later

# 3. Reinstall Rust core
cd rust-core
cargo clean
cargo build --release

# 4. Check for missing dependencies
otool -L target/release/libosx_core.dylib
```

## Error Recovery Scenarios

### FFI Operation Failures

**Scenario 1: Transient Memory Allocation Failure**

**Symptoms**:
```
FFI operation failed with transient error (attempt 1/3): Memory allocation failed
```

**Recovery**:
- System automatically retries up to 3 times
- Uses exponential backoff (0.5s, 1s, 1.5s)
- If all retries fail, returns error to caller

**User Action**:
- Wait for automatic retry
- If persists, restart application to free memory

**Scenario 2: Threading Error**

**Symptoms**:
```
FFI operation failed with transient error (attempt 2/3): Threading error occurred
```

**Recovery**:
- Automatic retry with backoff
- Releases thread resources between retries
- Succeeds after contention resolves

**User Action**:
- None required (automatic)
- Monitor logs for pattern of failures

**Scenario 3: Permanent FFI Error**

**Symptoms**:
```
RustBridgeError.invalidString: String contains null byte
```

**Recovery**:
- No retry (permanent error)
- Fails immediately
- Returns error to user

**User Action**:
- Fix input data (remove null bytes)
- Report bug if unexpected

### Network Operation Failures

**Scenario 1: Network Timeout**

**Symptoms**:
```
Network request failed (attempt 1/5), retrying in 1.0s: The request timed out
```

**Recovery**:
- Exponential backoff: 1s, 2s, 4s, 8s, 16s
- Jitter added to prevent thundering herd
- Max delay: 60 seconds

**User Action**:
- Wait for automatic retry
- Check network connection if all retries fail

**Scenario 2: Rate Limiting (HTTP 429)**

**Symptoms**:
```
HTTP 429 Too Many Requests
Retry-After: 60
```

**Recovery**:
- System respects `Retry-After` header
- Waits recommended time before retry
- Continues exponential backoff if header missing

**User Action**:
- Wait for automatic recovery
- Reduce request frequency if persistent

**Scenario 3: Server Error (HTTP 500)**

**Symptoms**:
```
Network request failed (attempt 2/5), retrying in 2.3s: Internal Server Error
```

**Recovery**:
- Automatic retry with backoff
- Server may recover during retry window
- Succeeds when server is healthy again

**User Action**:
- Wait for automatic retry
- Contact server admin if persistent

### File Operation Failures

**Scenario 1: File Locked by Another Process**

**Symptoms**:
```
File operation failed (attempt 1/3), retrying: NSFileLockingError
```

**Recovery**:
- Retries 3 times with 0.5s delay
- Lock may be released during retry
- Succeeds when file becomes available

**User Action**:
```bash
# Identify process locking file
lsof | grep <filename>

# If safe, close the locking application
```

**Scenario 2: Permission Temporarily Unavailable**

**Symptoms**:
```
File operation failed (attempt 2/3), retrying: NSFileReadNoPermissionError
```

**Recovery**:
- System retries operation
- Permission may become available (system delay)
- Succeeds after system grants access

**User Action**:
- Wait for automatic retry
- Check file permissions if persistent:
```bash
ls -l <file>
chmod +r <file>  # If needed
```

**Scenario 3: Resource Busy (EBUSY)**

**Symptoms**:
```
File operation failed (attempt 1/3), retrying: Resource busy
```

**Recovery**:
- Automatic retry with delay
- Resource may become free
- Continues with other files if ultimately fails

**User Action**:
- None required for automatic retry
- If persistent:
```bash
# Check what's using the resource
lsof +D <directory>
```

### Partial Cleanup Failures

**Scenario: Some Files Cannot Be Deleted**

**Symptoms**:
```
Cleanup completed: 45 files, 3 directories, 250MB freed
Errors: 2 items failed
```

**Recovery**:
- System continues with remaining items
- Collects all errors
- Returns partial success result

**User Action**:
```swift
let result = try await cleanerService.clean(with: config)

for error in result.errors {
    print("Failed: \(error.path)")
    print("Reason: \(error.reason)")
}

// Retry failed items manually if needed
for error in result.errors {
    try await FileOperationRetry.remove(error.path, maxAttempts: 5)
}
```

## Performance Issues

### Slow Cleanup Operations

**Symptoms**:
- Cleanup takes significantly longer than expected
- System reports "Using Swift fallback"

**Diagnosis**:
```bash
# Check if Rust core is active
grep "fallback" /var/log/osxcleaner.log

# Measure performance
time osxcleaner clean --level normal ~/Library/Caches
```

**Resolution**:
1. Verify Rust core is initialized (not in fallback mode)
2. Rebuild Rust core for optimizations:
```bash
cd rust-core
cargo build --release
```

3. Check system load:
```bash
top -o cpu
# Ensure CPU not maxed out
```

### High Memory Usage

**Symptoms**:
- Application uses > 500MB RAM
- System shows memory pressure

**Diagnosis**:
```bash
# Monitor memory usage
memory_pressure

# Check app memory
ps aux | grep osxcleaner
```

**Resolution**:
1. Restart application to free accumulated memory
2. Reduce concurrent operations:
```swift
let config = CleanerConfiguration(
    maxConcurrentOperations: 2  // Reduce from default 4
)
```

3. Process in smaller batches

## Network Issues

### Cannot Connect to MDM Server

**Symptoms**:
```
Network request failed after 5 attempts: Cannot connect to host
```

**Diagnosis**:
```bash
# Test connectivity
ping mdm.example.com

# Test HTTPS
curl -I https://mdm.example.com/api/health

# Check DNS
nslookup mdm.example.com
```

**Resolution**:
1. Verify network connection
2. Check firewall settings:
```bash
# macOS Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Allow osxcleaner if blocked
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/osxcleaner
```

3. Check VPN/proxy configuration
4. Verify SSL certificates are valid

## File System Issues

### Insufficient Permissions

**Symptoms**:
```
NSFileWriteNoPermissionError: You don't have permission to save the file
```

**Resolution**:
```bash
# Check permissions
ls -l <file>

# Fix ownership (if appropriate)
sudo chown $USER <file>

# Add read/write permission
chmod u+rw <file>

# For system directories, may need TCC permission
# System Preferences → Security & Privacy → Full Disk Access
```

### Disk Full

**Symptoms**:
```
POSIX error ENOSPC: No space left on device
```

**Resolution**:
```bash
# Check disk space
df -h

# Find largest files
du -sh /* | sort -h | tail -10

# Clean up space manually
# Then retry operation
```

### File System Corruption

**Symptoms**:
- Unexpected file operation failures
- Inconsistent file listings

**Resolution**:
```bash
# Run First Aid
diskutil verifyVolume /
diskutil repairVolume /

# Check SMART status
diskutil info disk0 | grep SMART

# If corrupted, backup and reformat
```

## Build and Installation

### Swift Build Failures

**Symptoms**:
```
error: build had 1 command failures
```

**Resolution**:
```bash
# Clean build
swift package clean
rm -rf .build/

# Rebuild
swift build --configuration release

# If still fails, check Xcode
xcode-select --print-path
# Should be: /Applications/Xcode.app/Contents/Developer
```

### Rust Build Failures

**Symptoms**:
```
error: could not compile `osx-core`
```

**Resolution**:
```bash
# Update Rust
rustup update stable

# Clean Rust build
cd rust-core
cargo clean

# Rebuild
cargo build --release

# Check for dependency issues
cargo check
```

### Test Failures

**Symptoms**:
```
Test Suite 'All tests' failed
```

**Resolution**:
```bash
# Run specific test
swift test --filter ErrorRecoveryTests

# Verbose output
swift test --verbose

# Check for flaky tests
swift test --parallel

# If integration tests fail, check services
pgrep osxcleaner
```

## Diagnostic Tools

### Logging

Enable detailed logging:

```swift
// Set log level
AppLogger.shared.setLevel(.debug)

// Check logs
tail -f /var/log/osxcleaner.log
```

### System Information

```bash
# System version
sw_vers

# Hardware info
system_profiler SPHardwareDataType

# Disk info
diskutil list

# Network info
ifconfig
netstat -rn
```

### Performance Profiling

```bash
# CPU profiling
instruments -t "Time Profiler" osxcleaner

# Memory profiling
instruments -t "Allocations" osxcleaner

# File I/O profiling
instruments -t "File Activity" osxcleaner
```

### Recovery Metrics

```swift
// Check recovery statistics
let stats = RecoveryMetrics.shared.getStatistics()
print("Total retries: \(stats.totalRetries)")
print("Success rate: \(stats.successRate)%")
print("Average attempts: \(stats.averageAttempts)")
```

## Getting Help

If issues persist after troubleshooting:

1. **Collect diagnostic information**:
```bash
# System info
sw_vers > diagnostic.txt
system_profiler SPHardwareDataType >> diagnostic.txt

# Logs
tail -100 /var/log/osxcleaner.log >> diagnostic.txt

# Rust core status
ls -la rust-core/target/release/ >> diagnostic.txt
```

2. **Create GitHub issue**: https://github.com/kcenon/osx_cleaner/issues

3. **Include**:
   - Diagnostic information
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages/logs

## See Also

- [ERROR_RECOVERY.md](./ERROR_RECOVERY.md) - Error recovery mechanisms
- [TESTING.md](./TESTING.md) - Testing guide
- [SECURITY.md](./SECURITY.md) - Security guide

---

**Version**: 1.0.0
**Last Updated**: 2026-02-02
**Maintained By**: OSX Cleaner Team
