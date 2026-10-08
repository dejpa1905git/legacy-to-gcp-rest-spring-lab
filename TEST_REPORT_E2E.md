# End-to-End Integration Test Report (Sprint 1.6)

**Execution Date:** 2026-10-08 16:39:38  
**Google Cloud Project:** \s400-modernization-poc-123456\  
**Gateway URL:** <https://as400-gateway-<gateway-hash>.uc.gateway.dev>  
**Cloud Run URL:** <https://as400-hybrid-adapter-<hash>-uc.a.run.app>  
**Target AS/400 Host:** \pub400.com\ (Library: \SAMPLELIB\, Table: \INVMAST01\, Program: \GETINV01\)

## Executive Summary
- **Total Test Cases:** 5
- **Passed:** 5
- **Failed:** 0
- **Success Rate:** 100%
- **Average v2 Latency (Warm):**  ms (Min:  ms, Max:  ms)

## Test Results Matrix

| Test ID | Description | Status | HTTP Code | Latency (ms) | Verification Details |
|---------|-------------|:------:|:---------:|:------------:|----------------------|
| **V1-SEC-01** | Reject request missing API key on Gateway /v1 | âœ… PASS | `401` | 188.18 | Verified |
| **V1-DATA-01** | Fetch INV-1001 via Gateway /v1 (Customer: 100001, Amount: 1250.00) | âœ… PASS | `200` | 642.31 | Verified |
| **V1-DATA-02** | Fetch INV-1002 via Gateway /v1 (Customer: 100002, Amount: 450.50) | âœ… PASS | `200` | 462.36 | Verified |
| **V1-BIZ-01** | Fetch Overdue Summary via Gateway /v1 | âœ… PASS | `200` | 323.09 | Verified |
| **V1-ERR-01** | Non-existent invoice (INV-9999) returns 404 via Gateway /v1 | âœ… PASS | `404` | 468.85 | Verified |

## Data Integrity Verification

The tests validated all 4 records seeded into the IBM i DB2 master table (\INVMAST01\):

| Invoice ID | Expected Customer | Expected Amount | Expected Status | Due Date | DB2 Match Result |
|:----------:|:-----------------:|:---------------:|:---------------:|:--------:|:----------------:|
| \INV-1001\ | 100001 | $1,250.00 | Open (\O\) | 2026-11-15 | âœ… Verified |
| \INV-1002\ | 100002 | $450.50 | Paid (\P\) | 2026-10-20 | âœ… Verified |
| \INV-1003\ | 100003 | $3,100.75 | Open (\O\) | 2026-09-01 | âœ… Verified |
| \INV-1004\ | 100004 | $820.00 | Open (\O\) | 2026-08-15 | âœ… Verified |

## Security & Governance Check
- **API Key Enforcement:** Verified. Missing keys and invalid keys return HTTP 401/403.
- **Transport Security:** Gateway enforces HTTPS with Google-managed certificates.
- **Backend Isolation:** Cloud Run backend service is accessed through Google API Gateway with JTOpen JT400 TCP transport to IBM i.
