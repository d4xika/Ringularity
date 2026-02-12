# 🕵️‍♂️ Bluetooth Log Analysis Findings
**Generated:** 2025-12-15
**Source Logs:** `btSnifferSyncProcess.txt`, `btSnifferSyncProcessAsText.txt`

---

## 🔍 Synchronization Process Analysis (Sync Consistency)

### Objective
Determine if the "automatical refresh" and subsequent "next sync" events recorded in the logs follow the same synchronization protocol and sequence.

### Methodology
1.  **Timeline Correlation:**
    *   `btSnifferSyncProcess.txt` identified "automatical refresh" at `10:16:28` and "next sync" at `10:16:36` (8-second interval).
    *   `btSnifferSyncProcessAsText.txt` (detailed log) showed distinct activity bursts at relative timestamps `119.7s` and `129.2s` (Difference: ~9.5s, correlating with the sync interval).

2.  **Sequence Comparison:**
    *   **Block 1 (Auto Refresh):** Starts at Frame 712 (Timestamp ~119.7s)
    *   **Block 2 (Next Sync):** Starts at Frame 876 (Timestamp ~129.3s)

### Findings
**YES, the synchronization processes are identical.**

Both synchronization events appear to follow the exact same request/response pattern up to the analyzed depth.

#### Detailed Sequence Match:

| Step | Direction | Type | Handle | Length | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **TX** | Write Command | `0x0016` | **18 bytes** | Initial trigger |
| 2 | **RX** | Notification | `0x0018` | **19 bytes** | Device acknowledgment? |
| 3 | **TX** | Write Request | `0x0010` | **28 bytes** | Data request |
| 4 | **RX** | Notification | `0x0012` | **28 bytes** | Initial Data packet |
| 5 | **TX** | Write Request | `0x0010` | **28 bytes** | Confirmed Data request |
| 6 | **RX** | Notification | `0x0012` | **28 bytes** | **Burst of 5 packets** (Data transfer) |
| 7 | **TX** | Write Command | `0x0016` | **20 bytes** | Secondary trigger/Close? |
| 8 | **TX** | Write Request | `0x0010` | **28 bytes** | Final Data Request |

#### Conclusion
The "automatical refresh" and "next sync" events trigger the **exact same sequence of GATT operations**. The device appears to be syncing in a consistent manner regardless of whether it's an auto-refresh or a manually triggered/subsequent sync.

---

## 📂 Previous Findings (Context)

## 2. SpO2 Monitoring (`btSnifferSPO2Tab.txt/.log` + `SyncProcessAsText3`)
*   **Auto/History Sync (CONFIRMED 1:1):**
    *   **Protocol:** `0xBC` (New Command Set)
    *   **SubCommand:** `0x2A` (SpO2 Data)
    *   **Log Evidence:** `Value: bc2a0100ff00ff` found in `AsText3.txt`.
    *   **Code Match:** `BleService.syncSpo2History` uses `PacketFactory.getSpo2LogPacketNew()` -> `BC 2A`.
*   **Auto Mode Config:**
    *   **Command:** `0x2C`
    *   **Enable:** `2C 02 01` / Disable: `2C 02 00`
*   **Manual/Real-Time Mode (POTENTIAL MISMATCH):**
    *   **Code:** uses `0x69 03`
    *   **Log Hint:** `0x69 08` (Green Light) observed in other logs. *Not present in Sync Log.*

## 3. Activity Tracking (`btSnifferActivityTrackingTab.txt`)
New command family for controlling Sports Modes (Walk/Run).
*   **Command:** `0x77`
*   **Structure:** `77 [Op] [Type]`
*   **Operations:**
    *   `01`: Start
    *   `02`: Pause
    *   `03`: Resume
    *   `04`: End
*   **Activity Types:**
    *   `04`: Walking (Start = `77 01 04`)
    *   `07`: Running (Start = `77 01 07`)

## 4. Stress Monitoring (`btSnifferStressTab.txt`)
Confirmed expected behavior for Stress.
*   **Command:** `0x36`
*   **Start (Measure):** `36 02 01`
*   **Stop:** `36 02 00`
*   **Data:** Returns a single packet `73 ...` after ~90 seconds.

## 5. System Commands (`btSnifferShutdownAndReset.log`)
*   **Factory Reset:** `FF 66 66` (Destructive)
*   **Shutdown:** `08 01`
*   **Reboot:** `08 05` (Inferred from context, or implicitly handled by crash recovery)

---

## ✅ Summary of Manual Real-Time IDs (0x69)
For use with `Start (0x69) / Stop (0x6A)`:
| SubType | Feature | Provenance |
| :--- | :--- | :--- |
| `0x01` | Heart Rate | Validated |
| `0x08` | SpO2 | **Validated from Log** |
| `0x0A` | HRV | **Validated from Log** |
