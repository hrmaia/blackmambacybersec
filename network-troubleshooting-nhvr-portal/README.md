# Network Packet Analysis: TLS Connection Failure Due to Path MTU / Fragmentation Issues

**Case Study – Network Troubleshooting Portfolio**
**Author:** Hebert Maia
**Date:** August 2026
**Tools Used:** Wireshark, TCP/IP knowledge, TLS analysis

---

## 1. Scenario Overview

A client on the internal network (`192.168.0.140`) attempted to establish a secure connection to the National Heavy Vehicle Regulator (NHVR) portal at `portal.nhvr.gov.au` (`20.211.113.81`).

The connection failed during the TLS handshake. Packet capture analysis revealed a classic **Path MTU Discovery (PMTUD)** failure combined with TCP retransmission behaviour.

This write-up documents the full analysis of the capture, root cause identification, and recommended remediation steps.

---

## 2. Environment

| Item                    | Value                          |
|--------------------------|----------------------------------|
| Client IP               | 192.168.0.140                  |
| Gateway / Router        | 192.168.0.254                  |
| Destination Server      | 20.211.113.81                  |
| Destination Hostname    | portal.nhvr.gov.au             |
| Protocol                | TLSv1.2                        |
| Capture Tool            | Wireshark                      |

---

## 3. Packet Capture Timeline (Key Frames)

| Time (approx) | Source          | Destination     | Protocol | Key Info |
|----------------|------------------|-------------------|----------|----------|
| 105.353599     | 192.168.0.140    | 20.211.113.81     | TLSv1.2  | **Client Hello** (SNI=portal.nhvr.gov.au) – Length 354 |
| 105.354388     | 192.168.0.254    | 192.168.0.140     | ICMP     | **Destination unreachable (Fragmentation needed)** |
| 105.371150     | 20.211.113.81    | 192.168.0.140     | TCP      | Dup ACK |
| 105.378260     | 192.168.0.140    | 20.211.113.81     | TCP      | **TCP Retransmission** of Client Hello |
| 105.378430     | 192.168.0.140    | 20.211.113.81     | TCP      | TCP Retransmission (smaller segment) |
| 105.396265     | 20.211.113.81    | 192.168.0.140     | TCP      | ACK |
| Later frames   | Both sides       | Both sides        | TCP/SSL  | Additional retransmissions, Dup ACKs, and finally FIN/ACK (connection closed) |

---

## 4. Detailed Analysis

### 4.1 Initial TLS Client Hello
The client initiates a TLS 1.2 handshake by sending a **Client Hello** message containing the Server Name Indication (SNI) extension for `portal.nhvr.gov.au`.

The packet size (354 bytes) is relatively large for a Client Hello. Modern Client Hello messages often exceed 200–300 bytes due to multiple cipher suites, supported groups, signature algorithms, and extensions.

### 4.2 ICMP "Fragmentation Needed"
Immediately after the Client Hello, the local gateway (`192.168.0.254`) replies with an ICMP Type 3 / Code 4 message:

> Destination unreachable (Fragmentation needed)

This indicates that:

- The outgoing packet was larger than the Path MTU of the next hop.
- The IP "Don't Fragment" (DF) bit was set (normal behaviour for TCP and PMTUD).
- The router could not fragment the packet and therefore dropped it, notifying the sender.

### 4.3 TCP Behaviour After the ICMP Message
Instead of reducing the segment size and retransmitting a smaller Client Hello, the client continues to retransmit the original (or similarly sized) segment. This results in:

- Multiple **TCP Retransmissions**
- **Duplicate ACKs** from the server
- Eventual connection teardown (FIN/ACK exchange)

This pattern is characteristic of a **PMTUD black hole** or incomplete handling of the ICMP Fragmentation Needed message by the client operating system / TCP stack.

---

## 5. Root Cause

**Primary Cause:** Path MTU Discovery failure.

The large TLS Client Hello exceeded the effective Path MTU between the client and the destination. The gateway correctly signalled "Fragmentation needed", but the client did not properly lower its Maximum Segment Size (MSS) and retransmit a smaller packet.

Contributing factors that commonly cause this behaviour:

- Incorrect or missing ICMP handling on the client
- Firewall / security device dropping ICMP Fragmentation Needed messages
- VPN, tunnel, or overlay network reducing the effective MTU without proper MSS clamping
- Overly large Client Hello (many TLS extensions)

---

## 6. Impact

- Secure connection to the NHVR portal could not be established.
- User experience: timeout or "connection failed" error in the browser / application.
- Repeated retransmissions increase network load and latency.

---

## 7. Recommended Resolution Steps

1. **Verify Path MTU**
   ```bash
   # From the client
   ping -M do -s 1472 20.211.113.81   # Test with DF bit set
   ```

2. **Enable / Fix MSS Clamping** on the gateway or VPN concentrator (especially important if a tunnel is in use).

3. **Ensure ICMP Type 3 Code 4 is allowed** through any intermediate firewalls.

4. **Reduce Client Hello size** (temporary workaround):
   - Disable unnecessary TLS extensions
   - Limit cipher suites if possible

5. **Lower the interface MTU** on the client as a last resort (e.g., 1400) and test connectivity.

6. **Monitor with Wireshark** after changes to confirm the Client Hello is now successfully delivered and the Server Hello is received.

---

## 8. Skills Demonstrated

- Deep packet inspection with Wireshark
- Understanding of TCP retransmission and congestion control behaviour
- Knowledge of Path MTU Discovery (PMTUD) and ICMP Fragmentation Needed
- TLS handshake analysis (Client Hello / SNI)
- Systematic root-cause analysis of network connectivity failures
- Documentation of technical findings in a clear, professional format

---

## 9. Conclusion

This case study illustrates how a seemingly simple "website won't load" issue can be caused by a subtle interaction between large TLS Client Hello packets and Path MTU Discovery. Proper packet analysis quickly revealed the root cause and provided a clear path to resolution.

Understanding these low-level network behaviours is essential for effective troubleshooting in modern enterprise and cloud environments.
