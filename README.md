# Cybersecurity Lab Projects

A collection of three Bash automation tools built during the **Cybersecurity specialization** of my B.A. in Management Information Systems (Cyberium Arena / ThinkCyber). Each project automates a different part of a network security assessment. They are included here to demonstrate hands-on technical ability and structured implementation — scripting and automation, operational design, input validation, modular structure, and reviewable output — with the security tooling as the context in which those skills were applied.

**Author:** Alisiya Rabinovich — B.A. in Management Information Systems (Cybersecurity specialization)

---

## Projects

| Project | Focus | Core techniques | Key tools |
|---------|-------|-----------------|-----------|
| **[CHECKER](./checker/)** | Attack simulation & activity logging | Host discovery, TCP/UDP scanning, SSH weak-credential testing, bounded SYN flood, controlled ARP spoofing — all logged | Nmap, Hydra, Hping3, Arpspoof |
| **[VULNER](./vulner/)** | Network scanning & vulnerability mapping | Service/version detection, weak-credential checks, NSE + Searchsploit mapping, searchable report, Zip export | Nmap, Hydra, Searchsploit, Zip |
| **[GhostLogin](./ghostlogin/)** | Automated SSH exposure assessment | SSH discovery, controlled credential testing, non-interactive post-access gathering | Nmap, Hydra, sshpass |

### CHECKER — Attack Simulation & Activity Logging
A menu-driven tool that discovers hosts on the local network and runs one of **five** controlled operations (TCP Port Scan, UDP Scan, SSH Weak Credentials, SYN Flood, ARP Spoofing) across four attack classes, recording every executed action to `/var/log/checker.log`. It is a lab attack-simulation and logging tool, not a SOC monitoring or detection platform.

### VULNER — Automated Network Scanning & Vulnerability Mapping
An assessment tool with **Basic** and **Full** scan modes. It validates the target scope, discovers active hosts, detects services and weak credentials, and — in Full mode — maps *potential* vulnerabilities via NSE and Searchsploit. All findings go into a structured, searchable `results.txt` that can be exported as a Zip archive.

### GhostLogin — Automated SSH Exposure & Credential Assessment
A tool that scans a user-defined subnet for exposed SSH, tests common credentials against discovered hosts, and runs non-interactive post-access commands on a successful login — with handling for missing tools, a missing wordlist, and unreachable hosts.

## Themes across the projects

These are genuinely technical cybersecurity projects, and they also show the engineering discipline around the tooling:

- **Network security assessment** — host discovery, port/service scanning, weak-credential testing, and vulnerability indicator mapping, using standard tools (Nmap, Hydra, Hping3, Arpspoof, Searchsploit, sshpass).
- **Modular Bash automation** — each operation or stage lives in its own function behind a clear control flow, which keeps the tools readable and maintainable.
- **Input validation & scope control** — user input is validated (IPv4, CIDR, menu choices, subnet masks), and the tools constrain themselves to an intended scope. These are **technical controls, not authorization**.
- **Defined controls and their limits** — e.g. CHECKER bounds its SYN burst to a fixed packet count and restores IP forwarding on the ARP operation's normal completion path; VULNER bounds its UDP scan with limited retries and a host timeout. Each project's README documents what these controls do *and do not* guarantee.
- **Logging, reporting & retrieval** — structured logs and reports, in-report keyword search, and Zip export turn raw tool output into reviewable artifacts.

## About this portfolio

These are authentic cybersecurity projects completed as part of the **Cybersecurity specialization** within my B.A. in Management Information Systems. I include them here because they demonstrate hands-on technical ability and structured implementation — the cybersecurity domain is the context, and the transferable engineering skills are the point.

Across the three projects, the work demonstrates:

- **Scripting and automation** — non-trivial Bash tools that chain multiple stages into a single automated flow.
- **Structured problem-solving** — decomposing a task into ordered, single-responsibility steps and reasoning about edge cases and failure modes.
- **Workflow and process design** — designing the operational logic of each tool before implementation.
- **Input validation** — validating and sanitizing user input (IPv4, CIDR, menu choices, subnet masks) before acting on it.
- **Logging and reporting** — producing structured logs, clean summaries, and searchable/exportable reports.
- **Integration of technical tools** — coordinating several command-line tools behind one consistent interface and normalizing their output.
- **Technical documentation** — clear, accurate write-ups of how each tool works, its decisions, and its limitations.
- **Troubleshooting** — anticipating and handling missing dependencies, unreachable hosts, and other runtime conditions.

My broader interests are in systems analysis, technical/IT project management, AI-related implementation, and solution-oriented technical roles; these projects are included as evidence of the technical foundation behind that work, not as a pursuit of a cybersecurity-specialist career.

Each project folder contains the Bash script, a detailed README, lab screenshots in `assets/`, and the cleaned original project report in `docs/`.

## Repository structure

```text
cybersecurity-lab-projects/
├── README.md
├── checker/
│   ├── README.md
│   ├── checker.sh
│   ├── assets/        # lab screenshots
│   └── docs/          # checker-project-report.pdf
├── vulner/
│   ├── README.md
│   ├── vulner.sh
│   ├── assets/
│   └── docs/          # vulner-project-report.pdf
└── ghostlogin/
    ├── README.md
    ├── ghostlogin.sh
    ├── assets/
    └── docs/          # ghostlogin-project-report.pdf
```

## Educational use & authorization

Every tool here is an **educational project built and run in an authorized laboratory environment** on a private (RFC1918) test network, and is published to document what was built and learned. These are offensive-security techniques studied for a defensive purpose — understanding how attacks work in order to detect, log, and defend against them.

The scope restrictions and bounded operations in these scripts are technical controls; they are **not** a form of authorization. **Do not run any of these tools against systems, networks, or devices you are not explicitly authorized to test.** Unauthorized scanning, credential testing, denial-of-service, or man-in-the-middle activity is illegal in most jurisdictions.

Some screenshots preserve deliberately weak **lab demonstration** credentials (e.g. test usernames and passwords on private IP addresses) as evidence of functionality. These are not credentials for any real or production system.
