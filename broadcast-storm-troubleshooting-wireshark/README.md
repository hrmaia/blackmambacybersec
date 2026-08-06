# Broadcast Storm Troubleshooting with Wireshark

**Network Troubleshooting Portfolio Project**
Hands-on analysis and resolution of a Layer-2 broadcast storm using Wireshark.

---

## Project Overview

This project documents the complete process of identifying, analyzing, and resolving a broadcast storm on a local area network. Broadcast storms can quickly saturate bandwidth, cause high latency, packet loss, and make devices unresponsive.

Using Wireshark as the primary analysis tool, I captured live traffic, applied targeted filters, examined statistics, identified the root cause, and applied corrective actions.

**Skills Demonstrated**
- Packet capture and analysis with Wireshark
- Layer-2 troubleshooting (broadcast domains, MAC addresses, switching loops)
- Use of display filters, statistics, and conversations
- Root cause analysis and remediation
- Network best practices (Spanning Tree Protocol, storm control)

---

## Scenario / Problem Statement

**Environment**
Small office / lab network consisting of:
- 1 × Managed switch (VLAN 10 – Users)
- 1 × Unmanaged switch (recently added)
- Multiple Windows and Linux clients
- DHCP server and network printers on the same subnet

**Symptoms Reported**
- Sudden severe network slowdown
- High latency and intermittent connectivity
- Some devices (especially printers and DHCP clients) becoming completely unresponsive
- Network utilization spikes to near 100% on the affected segment

The issue started shortly after a second cable was connected between the managed and unmanaged switches (creating a physical loop). Spanning Tree Protocol (STP) was not enabled on the managed switch, allowing the loop to form.

---

## Tools Used

| Tool              | Purpose                                      |
|-------------------|-----------------------------------------------|
| Wireshark         | Packet capture and deep analysis             |
| Switch CLI        | Port status, MAC address table, STP status   |
| ping / traceroute | Initial connectivity and path testing        |
| (Optional)        | PingPlotter for visual hop analysis          |

---

## Methodology

### 1. Initial Capture
- Connected a laptop to a free port on the managed switch (same VLAN).
- Started Wireshark on the active network interface.
- Optional capture filter used: `broadcast or multicast` (to reduce volume).
- Captured traffic for 10–15 seconds during the peak of the symptoms.

### 2. Confirming a Broadcast Storm
Applied the display filter:

```
eth.dst == ff:ff:ff:ff:ff:ff
```

**Observations from Statistics → Summary**:
- Broadcast packets made up a very high percentage of total traffic (often >40–50%).
- Packet rate reached hundreds to thousands of broadcasts per second.
- Clear indication of a broadcast storm.

### 3. Identifying the Source
- Went to **Statistics → Conversations → Ethernet**.
- Sorted by number of packets / bytes.
- Identified the top source MAC addresses generating the majority of broadcast frames.
- Most frames were ARP requests (common in storm scenarios) or repeating frames circulating due to the loop.

Key indicators of a switching loop:
- Same frames appearing repeatedly with increasing TTL (or "no response found" on ICMP probes).
- Extremely high volume of identical broadcast frames.

### 4. Root Cause
A physical Layer-2 loop was created by the redundant cable between the managed and unmanaged switches. Because STP was disabled (or not configured), broadcast frames were endlessly flooded, multiplying with every pass through the loop and consuming all available bandwidth.

---

## Resolution Steps

1. **Immediate Mitigation**
   - Located and disconnected the redundant cable that formed the loop.
   - Broadcast traffic dropped dramatically within seconds.

2. **Permanent Fixes**
   - Enabled Spanning Tree Protocol (RSTP preferred) on the managed switch.
   - Configured storm control on switch ports (limit broadcast/multicast rate).
   - Verified no other physical loops existed.
   - (Optional) Segmented chatty devices into a separate VLAN if needed.

3. **Verification**
   - Took a second Wireshark capture.
   - Confirmed broadcast rate returned to normal baseline levels.
   - Network performance (latency, connectivity, printer access) restored.

---

## Key Wireshark Filters Used

```wireshark
# All broadcasts
eth.dst == ff:ff:ff:ff:ff:ff

# ARP only
arp

# Broadcast + Multicast
eth.dst[0] & 1

# Specific source MAC (replace with actual)
eth.src == aa:bb:cc:dd:ee:ff
```

Useful menus:
- Statistics → Summary
- Statistics → Conversations (Ethernet / IPv4)
- Statistics → Protocol Hierarchy
- Statistics → I/O Graphs (to visualize the storm spike)

---

## Results & Findings

| Metric                          | During Storm          | After Resolution     |
|----------------------------------|------------------------|-----------------------|
| Broadcast packets/sec           | Hundreds–thousands    | Normal baseline      |
| % of traffic that is broadcast  | >40–50%               | Low single digits    |
| Network usability               | Severely degraded     | Fully restored       |

Root cause confirmed: Layer-2 loop due to missing STP + physical redundant link.

---

## Prevention Recommendations

- Always enable Spanning Tree Protocol (STP/RSTP/MSTP) on managed switches.
- Use storm-control features on switch ports.
- Avoid connecting unmanaged switches in ways that can create loops.
- Monitor broadcast rates (threshold alerts are useful).
- Keep broadcast domains reasonably small (VLANs help).
- Document physical cabling and redundant links.

---

## Lessons Learned

- Broadcast storms are primarily a Layer-2 problem and can bring an entire broadcast domain to a halt very quickly.
- Wireshark makes the invisible visible — statistics and conversations views are extremely powerful for rapid source identification.
- Prevention (STP + storm control) is far better than reactive troubleshooting.
- Always capture both during the incident and after remediation for clear before/after evidence.

---

## Repository Contents

```
├── README.md                 # This write-up
├── screenshots/              # Wireshark screenshots (Statistics, filters, I/O Graph, etc.)
├── captures/                 # Sample .pcap files (sanitized if possible)
└── notes/                    # Additional observations or switch configs
```

---

## How to Reproduce (Lab Setup)

1. Create a small topology with two switches (one managed, one unmanaged or two managed with STP disabled).
2. Connect two cables between them to form a loop.
3. Generate some broadcast traffic (ping broadcast address, or just let normal ARP/DHCP occur).
4. Capture with Wireshark and observe the storm.
5. Enable STP or remove the loop and re-capture.

---

**Author**: Hebert Maia
**Date**: August 2026
**Tools**: Wireshark, Switch CLI
**Category**: Network Troubleshooting / Packet Analysis
