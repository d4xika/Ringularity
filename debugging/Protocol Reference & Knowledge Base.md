# 💍 Colmi Ring R02 - Protocol Reference & Knowledge Base

**Last Updated:** 2025-12-12
**Status:** Working

---

## 1. ✅ Verified Commands (Control)

| Feature | Action | HEX Command | Behavior / Notes |
| :--- | :--- | :--- | :--- |
| **Heart Rate** | **Auto Mode** | `16 02 01 [Min]` | Enable Auto. `Min` = Minutes (05, 0A, 1E, 3C). |
| **Heart Rate** | **Manual Mode** | `16 02 00` | Disable Automatic / Stop Manual. |
| **SpO2** | **Auto Mode** | `2C 02 01` | Enable Automatic Monitoring. |
| **SpO2** | **Manual Mode** | `2C 02 00` | Disable Automatic / Stop Manual. |
| **Stress** | **Start** | `36 02 01` | **GOLDEN.** Start Measurement (Auto/Manual). |
| **Stress** | **Stop** | `36 02 00` | **GOLDEN.** Stop Measurement. |
| **HRV** | **Auto Mode** | `38 02 01` | **NEW!** Enable Scheduled HRV Monitoring. |
| **HRV** | **Manual Start** | `69 0A` | **Real-time** HRV/Stress Measurement. Stop: `6A 0A`. |
| **Sports** | **Start Walk** | `77 01 04` | Start "Walk" Activity. |
| **Sports** | **Start Run** | `77 01 07` | Start "Run" Activity. |
| **SpO2** | **Manual Start** | `69 08` | **Real-time** SpO2 Measurement (Red/Green?). Stop: `6A 08`. |
| **Config** | **Init** | `39 05` | Sent during pairing/binding. |
| **Binding** | **Request** | `48 00` | Bind Request/Check. Response `48 00 01` = Bound. |

> **⚠️ CRITICAL: MANUAL MODE vs AUTO MODE**
> *   **Auto/Periodic:** Uses configuration commands (`16`, `2C`, `36`, `38`).
> *   **Manual/Real-time:**
>     - **HR:** `69 01` (Start) / `6A 01` (Stop)
>     - **SpO2:** `69 08` (Start) / `6A 08` (Stop) - *Note: 0x08 often implies Green Light/PPI, but logs confirm this is used for SpO2.*
>     - **HRV:** `69 0A` (Start) / `6A 0A` (Stop)
> *   *Current App Recommendation:* Stick to Auto-Mode commands for stability unless Real-Time stream is needed.

---

## 2. 📊 Data Parsing (RX)

| Feature | Packet Header | Value Byte | Expected Behavior |
| :--- | :--- | :--- | :--- |
| **Heart Rate** | `0x69` | `data[4]` | Arrives ~1/sec. Check Index 4. If 0, check Index 2. |
| **SpO2** | `0x2C`? | `data[?]` | *Needs verification.* Likely similar to HR. |
| **Stress** | `0x73` | `data[1]` | **DELAYED.** Arrives ~90 seconds after Start. Value at Index 1 (e.g., `0x12` = 18). |
| **Raw Accel** | `0xA1` | Multiple | High-speed stream. Needs specialized parsing. |

---

## 3. 🧠 Quirks & Lessons Learned





## 4. 🧩 Verified Gadgetbridge Protocol Details

Based on `ColmiR0xConstants.java` and `ColmiR0xPacketHandler.java`:

### Control Commands
| Command | Name | Sub-Ops / Payload | Notes |
| :--- | :--- | :--- | :--- |
| **0x01** | Set Time | `YY MM DD HH MM SS` | `YY` is offset from 2000. |
| **0x03** | Get Battery | `03` | Response: `03 [Level] [ChargingState]` |
| **0x04** | Set Phone Name | `04 02 0A [NameBytes...]` | Used for initialization. |
| **0x0A** | User Settings | `0A 02 [Prefs...]` | Gender, Age, Height, Weight, BP, HR Alarm. |
| **0x08** | Power Off | `08 01` | Shuts down the ring. |
| **0x21** | Set Goals | `Step(4) Cal(4) Dist(4) Sport(2) Sleep(2)` | Little Endian integers. |
| **0x21** | Set Goals | `Step(4) Cal(4) Dist(4) Sport(2) Sleep(2)` | Little Endian integers. |
| **0x50** | Find Device | `50 55 AA` | Vibrates/Flashes ring. |
| **0xFF** | Factory Reset | `FF 66 66` | **Destructive.** Clears all data and settings. |

### Activity Tracking (0x77)
**New Discovery.** Real-time sports mode control.
*   **Structure:** `77 [Op] [Type]`
*   **Ops:** `01`=Start, `02`=Pause, `03`=Resume, `04`=End.
*   **Types:** `04`=Walk, `07`=Run.

### Auto-Monitoring / Config (0x16, 0x2C, 0x36)
Structure: `[Cmd] [Op] [Enable] [Interval?]`
*   **Op Codes:** `0x01` (Read?), `0x02` (Write).
*   **Enable:** `0x00` (Disable), `0x01` (Enable).
*   **0x16 (HR):** Payload includes Interval (mins).
*   **0x2C (SpO2)** & **0x36 (Stress):** Simple Enable/Disable.
*   **0x38 (HRV):** **NEW Discovery.** Scheduled HRV Monitoring. Enable (`02 01`) / Disable (`02 00`). Not present in older Gadgetbridge sources.

### Data Sync Commands
| Command | Data Type | Sub-Type | Notes |
| :--- | :--- | :--- | :--- |
| **0x43** | Activity History | - | **VERIFIED.** Samples every 15 mins. Byte 4 is `QuarterOfDay` index (0-95). |
| **0x37** | Stress History | - | **VERIFIED.** **NOT Set Time.** Returns history. **Quirk:** Packet 1 starts at Index 3, others at Index 2. |
| **0x15** | HR History | - | **VERIFIED.** Returns HR samples. |
| **0xBC** | Big Data V2 | `0x27` (Sleep) | Sleep Stages (Light/Deep/Awake). |
| **0xBC** | Big Data V2 | `0x2A` (SpO2) | **VERIFIED.** SpO2 History samples. |

### Notifications (0x73)
Server-initiated updates arriving on Notify Characteristic.
*   `73 01`: New HR Data Available.
*   `73 03`: New SpO2 Data Available.
*   `73 04`: New Steps Data Available.
*   `73 0C`: Battery Level Update.
*   `73 12`: Live Activity Update.

---

## 5. 🔮 Missing/Unknown
*   **0x48**: Explicitly **absent** from Gadgetbridge constants. Likely a factory/debug command or deprecated.
*   **0x2F**: `CMD_PACKET_SIZE`? Unclear usage.
