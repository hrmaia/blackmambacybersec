# Dark Web ID Alert Response Playbook

**Author:** Hebert Maia
**Portfolio Version | August 2026**

> ⚠️ Sanitized for portfolio purposes — the MSP's name and support phone
> number have been replaced with placeholders. Process, severity levels,
> and templates are unchanged from production use.

---

## 1. Scenario & Business Context

The MSP uses **Dark Web ID** (Kaseya / Datto) to monitor for company email addresses and credentials that appear on the dark web.

When an alert is raised, the current business decision is deliberately simple:

- Level 1 Helpdesk **only notifies** the user.
- The user is asked to assess whether the finding affects them.
- We recommend changing passwords if the user believes the exposed data has been reused.
- When a password is involved, we share the **first 3–4 characters** so the user can recognise it.
- We tell the user the **original breach source** (e.g. "a breach at Dropbox" or "a breach at Qantas") when it is known. If the source is unknown we clearly state that it has not been identified.
- If the user does not reply, the ticket is **automatically closed after 3 business days**.
- No forced password resets or account suspensions are performed by Level 1 unless the case is escalated.

This approach reduces ticket workload, avoids alarming users unnecessarily, and keeps the process practical for a Level 1 team while still providing clear escalation paths for higher-risk cases.

---

## 2. Severity Levels

| Severity   | Data Found                              | Main Risk                  |
|------------|-----------------------------------------|-----------------------------|
| **Low**    | Email only                              | Minimal                    |
| **Medium** | Email + Name / Date of Birth            | Phishing / Social Engineering |
| **High**   | Email + Password (cleartext or hashed)  | Account Takeover           |
| **Critical** | Email + Password + Sensitive PII (SSN, financial data, etc.) | Identity Theft |

---

## 3. General Steps for Every Alert

1. Log into Dark Web ID and review the alert (email, data leaked, date, original breach source).
2. Mark the alert as "In Progress".
3. Confirm the user exists and is active in Active Directory / Microsoft Entra ID.
4. Create or update the ticket in Kaseya BMS with severity and details.
5. Send the appropriate email template (see Section 5).
6. Document everything in the ticket.
7. If the user replies → handle the request or escalate.
   If no reply after **3 business days** → close the ticket automatically and note "No response – closed per policy".

---

## 4. Response by Severity

### Low Severity – Email Only
- Send Low Severity email.
- Note in user profile: "Email found on dark web – [date]".
- Close after 3 business days if no reply.

**Escalate if:** High-profile user, multiple recent breaches, or compromise < 30 days old.

### Medium Severity – Email + Name / DOB
- Send Medium Severity email.
- Advise user to watch for phishing.
- Flag account for monitoring (30 days).
- Close after 3 business days if no reply.

**Escalate if:** Recent compromise, high-profile user, or multiple users affected.

### High Severity – Email + Password
- Send High Severity email (include first 3–4 characters of the password).
- Ask user to check if they recognise the password and whether it has been reused.
- Recommend unique passwords for every site.
- **Always escalate to Level 2**.
- Ticket still auto-closes after 3 business days unless Level 2 keeps it open.

### Critical Severity – Email + Password + Sensitive PII
- Call the user first (leave voicemail + send email if unreachable).
- Send Critical Severity email (include first 3–4 characters of the password).
- Advise credit monitoring if the user believes they are affected.
- **Escalate immediately to Level 2 / SOC**.
- Ticket auto-closes after 3 business days unless Level 2 keeps it open.

---

## 5. Email Templates

### Low Severity Template

**Subject:** Notification: Your Email Found on Dark Web

Dear [User Name],

We have detected your email address ([email]) in a dark web listing. No passwords or other sensitive details were included.

This information appears to have been exposed from [breach source, e.g. a breach at Dropbox; or "The original breach source has not been identified"].

Please review whether this finding may affect you (for example if the same email is used on other services). We recommend using strong, unique passwords and enabling multi-factor authentication (MFA) wherever possible.

If you need any help or have questions, please contact us on [support phone number].
If we do not hear from you, this ticket will be closed automatically within 3 business days.

Thank you,
[MSP] Helpdesk

---

### Medium Severity Template

**Subject:** Notification: Personal Details Found on Dark Web

Dear [User Name],

Your email address ([email]) and some personal details (e.g. name / date of birth) have been found on the dark web. No passwords were exposed.

This information appears to have been exposed from [breach source, e.g. a breach at Qantas; or "The original breach source has not been identified"].

Please assess whether this may affect you and remain alert for phishing attempts. We recommend reviewing your passwords and enabling MFA.

If you need assistance, contact us on [support phone number].
If we do not hear from you, this ticket will be closed automatically within 3 business days.

Thank you,
[MSP] Helpdesk

---

### High Severity Template

**Subject:** Urgent Notification: Credentials Found on Dark Web

Dear [User Name],

Your email address ([email]) and a password starting with **[first 3–4 characters]** have been found on the dark web.

This information appears to have been exposed from [breach source, e.g. a breach at Dropbox; or "The original breach source has not been identified"].

Please check if you recognise this password and whether it has been reused on any other websites.
If you believe it has been reused, please reset those passwords and make each one unique.

If you need help, call us on [support phone number].
If we do not hear from you, this ticket will be closed automatically within 3 business days.

Thank you,
[MSP] Helpdesk

---

### Critical Severity Template

**Subject:** Critical Notification: Sensitive Information Found on Dark Web

Dear [User Name],

Your email address ([email]), a password starting with **[first 3–4 characters]**, and sensitive personal information have been found on the dark web.

This information appears to have been exposed from [breach source, e.g. a breach at Qantas; or "The original breach source has not been identified"].

Please assess the impact. If you believe you may be affected, consider placing a fraud alert or credit monitoring with the credit bureaus. Reset any reused passwords and make them unique.

Please contact us immediately on [support phone number] if you need assistance.
If we do not hear from you, this ticket will be closed automatically within 3 business days (we will continue monitoring on our side).

Thank you,
[MSP] Helpdesk

---

## 6. Microsoft Entra ID Quick Reference (Level 1)

| What to check                    | Where to look                                      | Required Role            |
|-----------------------------------|-----------------------------------------------------|---------------------------|
| User active / inactive           | Entra ID → Users → Last interactive sign-in time  | Reports Reader           |
| MFA status                       | Entra ID → Users → Authentication methods          | Authentication Admin     |
| Recent sign-in activity          | Entra ID → Monitoring & health → Sign-in logs      | Reports Reader           |
| Force password reset (escalated only) | Users → Reset password                        | Password Administrator   |
| Temporarily block sign-in (escalated only) | Users → Block sign-in                      | User Administrator       |

**Useful links**
- Entra admin centre: https://entra.microsoft.com
- User self-service MFA: https://mysignins.microsoft.com/security-info
- My Account: https://myaccount.microsoft.com

---

## 7. Level 2 Responsibilities (when escalated)

- Review Entra ID sign-in logs for suspicious activity.
- Collect indicators of compromise (IOCs) if relevant.
- Perform deeper analysis of the original breach if needed.
- Decide whether additional actions (forced reset, temporary block, legal notification) are required.
- Update threat intelligence / SIEM rules if patterns are found.
- Conduct a short post-incident review for Critical or multi-user cases.

---

## 8. Additional Notes

- **False positives** – Escalate to Level 2 for validation.
- **Multiple users in the same breach** – Escalate so Level 2 can assess broader impact.
- **User education** – After any interaction, gently remind users about MFA, unique passwords, and phishing awareness.
- Always record the breach source used in the email and any user reply in the ticket.

---

## 9. Design Decisions

This playbook was deliberately kept simple for Level 1 staff:

- No forced resets or account locks by Level 1 (reduces risk of locking out legitimate users and keeps the process light).
- Partial password (first 3–4 characters) is shared so users can recognise the credential without exposing the full password.
- Original breach source is included when known so users can take targeted action (e.g. change password on the affected service).
- 3-business-day auto-close keeps the helpdesk queue clean while still giving users a reasonable window to respond.
- Clear escalation paths ensure higher-risk cases still receive proper attention.

---

## 10. Document Control

| Version | Date       | Author              | Changes                          |
|---------|------------|----------------------|-----------------------------------|
| 1.0     | Aug 2026   | Helpdesk / DFIR      | Initial published portfolio version |

---

*This document is published as a professional example of a practical, real-world incident response playbook for a managed service provider environment. Contact: hebert@blackmambacyber.com*
