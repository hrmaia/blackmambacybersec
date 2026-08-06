# Network Troubleshooting Case Study
**Intermittent Website Access After Fibre Migration – MTU/MSS Issue**

**Author:** Hebert Maia

## Overview
A client reported that some websites were loading correctly while others failed to open. Basic connectivity tests (ping and DNS resolution) were successful, yet affected websites remained inaccessible. The issue was isolated to the client's network and was ultimately traced to an MTU mismatch introduced after a recent change to a fibre internet service.

This write-up documents the full troubleshooting process, from remote diagnosis through to on-site resolution.

---

## Scenario & Background

The client had recently switched internet service providers and moved from their previous connection to a fibre service. Shortly after the change, users began experiencing inconsistent website access:

- Some sites opened normally
- Other sites failed to load (browser would hang or time out)
- Ping to the affected websites succeeded
- DNS resolution was working correctly

The same websites loaded without issue when tested from an external network, confirming the problem was local to the client environment.

---

## Initial Remote Investigation

1. **Connectivity Verification**
   Confirmed that ICMP (ping) and DNS queries to the affected websites were successful. This ruled out basic Layer 3 reachability and name resolution problems.

2. **Firewall Rule Review**
   Inspected the firewall configuration and confirmed that the relevant traffic was permitted. No rules were blocking the destinations in question.

3. **Firewall Packet Capture**
   A packet capture was taken on the firewall. Some traffic violations were observed, but none that would theoretically prevent the websites from loading.

At this stage the root cause was still unclear, so an on-site visit was scheduled.

---

## On-Site Investigation

Arrived on site at approximately 03:50. Connected a laptop to the client network and opened Wireshark while attempting to access the failing websites.

The packet capture provided the critical evidence needed to identify the issue. Further testing was then performed to confirm the hypothesis.

### MTU / MSS Testing
Using ping with varying payload sizes (and the Do Not Fragment flag), the maximum usable MTU was determined. From that value the correct TCP Maximum Segment Size (MSS) was calculated.

---

## Root Cause

After the migration to fibre, the effective path MTU was lower than the previous connection. The firewall was not clamping the TCP MSS to a value that matched the new path MTU. As a result:

- TCP handshakes completed successfully (which is why ping and DNS worked)
- Larger packets (common with HTTPS and many modern websites) were being dropped silently along the path

This classic "black hole" behaviour explained why some sites worked and others did not.

---

## Resolution

1. Adjusted the MTU setting on the firewall to the value identified during testing.
2. Restarted the firewall to apply the change.
3. Retested all previously failing websites and confirmed they now loaded correctly.
4. Verified additional sites and general internet performance.

The issue was fully resolved.

---

## Tools Used

- Ping (with DF bit and variable payload sizes)
- Wireshark
- Firewall packet capture
- Browser developer tools (for initial confirmation)

---

## Key Takeaways

- A change in ISP (especially to fibre) frequently alters the effective path MTU. Always re-validate MTU/MSS after such migrations.
- Successful ping and DNS do **not** guarantee that larger TCP segments will pass.
- Packet captures remain one of the most effective ways to diagnose intermittent application-layer failures that appear "random".
- Early morning on-site work can be necessary when remote diagnostics reach a dead end.
