# VoIP Call Quality Troubleshooting Case Study
**Clinic → Mobile Client Calls – Asymmetric Audio Breakup Analysis**

**Author:** Hebert Maia
**Date:** August 2025
**Environment:** myCloudPBX (ECN Group) + Sophos Firewall + Internal LAN (192.168.65.0/23)
**Tools:** Wireshark, Sophos XG Firewall QoS, myCloudPBX Call Recordings

> ⚠️ Sanitized for portfolio purposes — the PBX server's public IP has been
> replaced with a placeholder. Client name withheld ("a medical clinic").

---

## 1. Scenario Overview

A medical clinic was experiencing frequent complaints about call quality on outbound calls from the clinic to clients' mobile phones:

- Calls were dropping
- Audio was choppy / breaking up
- Clients could not understand the receptionist clearly

The call flow was always the same:

```
Clinic Receptionist Phone  →  Internal Network  →  Sophos Firewall  →  myCloudPBX (Cloud)  →  Mobile Client
```

Interesting observation that unlocked the investigation:

| Recording Source              | Receptionist Voice | Client (Mobile) Voice |
|--------------------------------|---------------------|-------------------------|
| myCloudPBX Recording          | Breakup after ~1:30 | Clean                   |
| Wireshark Capture (Clinic LAN) | Clean               | Heavy breakup from start |

This directional asymmetry pointed strongly to a problem **between the clinic and the PBX**.

---

## 2. Investigation Timeline

### 2.1 Initial SIP Signalling Capture
Captured SIP traffic between the local phones (192.168.65.x) and the myCloudPBX server (placeholder IP `203.0.113.40`).
Observed:
- REGISTER, NOTIFY, OPTIONS messages
- Some phones using **TCP** as transport instead of the more common UDP
- All SIP responses were `200 OK` → signalling itself was healthy

### 2.2 RTP Stream Analysis
Assembled a full conversation in Wireshark and examined the RTP stream statistics:

- **Packet Loss:** 0%
- **Sequence Errors:** Present in some captures
- **Jitter:** Mean ~4 ms, but **Max Jitter** reached 35–77 ms
- **Max Delta:** Spikes up to 450+ ms
- Graph (Arrival Time vs Value) showed clear periodic spikes of high delay

### 2.3 Directional Comparison
Downloaded the call recording directly from myCloudPBX and compared it with the local Wireshark capture of the same call.
This confirmed the problem was **not** on the mobile side or inside the PBX media servers, but on the path **Clinic → PBX**.

---

## 3. Root Cause Analysis

After correlating all data, the main issues identified were:

1. **Insufficient / poorly tuned QoS** on the Sophos firewall
2. High jitter and occasional large inter-packet gaps on the uplink
3. Some phones using TCP for SIP (adding slight extra latency)
4. Network path between clinic and PBX introducing variable delay under load

The clinic had a solid 1 Gbps fibre connection and a /23 network, so raw bandwidth was **not** the problem. The issue was prioritisation and allocation of that bandwidth for real-time traffic.

---

## 4. Bandwidth Calculation (G.711a)

We standardised on the **G.711a** codec (most common in the environment).

| Metric                    | Value per call (one direction) | Notes |
|----------------------------|----------------------------------|-------|
| Base G.711a + overhead    | ~100–150 kbps                    | RTP + UDP + IP |
| Safety margin (20–30%)    | 120–195 kbps                     | Recommended |
| Converted to KBps         | **15 – 24.4 KBps**               | Sophos requires KBps |

**For 10 concurrent calls** (5 receptionists + 5 additional staff):

- Minimum total (one direction): **150 KBps**
- Limit total (one direction): **244 KBps**
- Both directions: **300 – 488 KBps**

---

## 5. Sophos QoS Configuration Recommendation

Because the bandwidth usage type is set to **Individual**:

```
Traffic Shaper Rule – Clinic VoIP
──────────────────────────────
Bandwidth Usage Type : Individual
Minimum              : 15 KBps
Maximum / Limit      : 24.4 KBps
Priority             : Highest (Real Time)
```

This guarantees each individual call gets between 15–24.4 KBps, which is the correct range for G.711a with a safety margin.

---

## 6. Additional Recommendations Implemented

- Verified all phones prefer UDP for SIP (where possible)
- Enabled / confirmed proper QoS marking (DSCP EF) on the phones
- Monitored the path Clinic → myCloudPBX with continuous ping + Wireshark during peak hours
- Kept a small amount of extra bandwidth reserved for SIP signalling

---

## 7. Results

After applying the individual QoS policy with the calculated values:

- Breakups on the receptionist's voice disappeared
- Client-side audio in local captures became clean
- No further complaints from staff or patients regarding call quality

---

## 8. Lessons Learned

1. Always compare **PBX recording** vs **local packet capture** — they tell different stories.
2. Zero packet loss does **not** mean good quality. High jitter and large deltas are enough to destroy a call.
3. When the firewall uses "Individual" bandwidth type, you must size the values **per call**, not for the total.
4. Even with 1 Gbps fibre, real-time traffic still needs explicit prioritisation.

---

## 9. Tools & Files Used

- Wireshark (SIP + RTP stream analysis)
- Sophos XG Firewall QoS
- myCloudPBX call recordings
- CSV exports of RTP statistics + jitter graphs

---

## 10. Conclusion

This case study demonstrates a complete real-world VoIP troubleshooting workflow: from SIP signalling analysis, through detailed RTP metrics, directional audio comparison, bandwidth calculation, and final firewall QoS tuning.

The combination of packet-level analysis and correct QoS sizing resolved a persistent call quality issue that affected both staff and patients.
