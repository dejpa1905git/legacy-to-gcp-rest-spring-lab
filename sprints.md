# Enterprise Migration POC - Case 1 (Encapsulation Pattern)

## Backlog

## In Progress
- [/] Sprint 2: Enterprise Security & Upstream Resilience Hardening
  - [X] Sprint 2.0: Upstream maintenance & fail-fast 503 Service Unavailable handling (commit e110800, verified live on Cloud Run Revision 3)
  - [X] Sprint 2.1: Enforce HTTP header-only API key security (strip query parameter extraction from OpenAPI spec, commit 73675d1)
  - [ ] Sprint 2.2: Lock down Cloud Run perimeter (IAM Service-to-Service authentication, `--no-allow-unauthenticated`)
  - [ ] Sprint 2.3: Store and rotate IBM i credentials using Google Cloud Secret Manager
  - [ ] Sprint 2.4: Enterprise connection pooling (`AS400ConnectionPool`) & Cloud Run workload capping
  - [ ] Sprint 2.5: Upstream fault tolerance via Resilience4j Circuit Breaker
- [/] Sprint 1.7: Record & edit 10-minute presentation video

## Done
- [X] Sprint 1.0: Initialize workspace directory structure in VS Code
- [X] Sprint 1.1: Setup PUB400 library & seed INVOICE_MASTER table
- [X] Sprint 1.2: Compile parameter-aware INVCALC.rpgle on PUB400
- [X] Sprint 1.3: Build local JT400 wrapper service (REST to RPG) inside as400-migration/hybrid-adapter/
- [X] Sprint 1.4: Configure local tunnel (ngrok) and OpenAPI spec inside gcp-infrastructure/
- [X] Sprint 1.5: Deploy GCP API Gateway with key authentication (gateway: as400-gateway-<gateway-hash>.uc.gateway.dev)
- [X] Sprint 1.5b: Deploy Spring Boot adapter to Google Cloud Run as /v2 production target
- [X] Sprint 1.6: End-to-end integration test & DB2 state verification (11/11 tests passed, 100% success rate)
- [X] Sprint 1.6b: Production documentation & Git/GitHub repository baseline (.gitignore, README.md, E2E report)