/// Synchronizer state. Decoding only runs while [locked].
enum SyncPhase { searching, synchronizing, locked }
