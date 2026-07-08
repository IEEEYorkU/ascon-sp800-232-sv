# Optimization Options Tracking

This document tracks potential hardware optimization proposals for the LASCON hardware accelerator. Each optimization option is documented below with its description, PPA (Performance, Power, Area) impact, required RTL/architectural changes, execution difficulty, and current status.

---

## Status Summary

| Status | Count |
| :--- | :---: |
| 🟢 **Completed** | 0 |
| 🟡 **In-Progress** | 0 |
| 🔵 **Pending** | 0 |
| 🔴 **Denied** | 0 |

---

## Optimization Template

To propose or track a new optimization, copy the markdown block below, append it to the [Optimizations Log](#optimizations-log) section, and fill in the details.

```markdown
### OPT-[ID]: [Title of Optimization]

> [!WARNING]  <!-- Optional: Use Alert box for critical status updates, e.g. Denied -->
> **Denied (YYYY-MM-DD):** [Reason for denial, e.g. Exceeded area budget]

#### Status
- [ ] **Pending**
- [ ] **In-Progress**
- [ ] **Completed**
- [ ] **Denied**

*Last Updated: YYYY-MM-DD*

#### Description
[Provide a clear description of the optimization and the core idea.]

#### PPA (Performance, Power, Area) Impact
- **Performance:** [e.g., Latency, throughput, frequency ($f_{max}$)]
- **Power:** [e.g., Dynamic power, static power]
- **Area:** [e.g., LUT/Register counts, memory blocks, overall gate count]

#### Required Changes
- [ ] Component A (e.g., `lascon_core`): [Details of change]
- [ ] Component B (e.g., `lascon_padder`): [Details of change]

#### Difficulty
- **Execution Difficulty:** Easy / Medium / Hard
- **Justification/Risks:** [Provide brief explanation of risk or design complexity]

#### Notes & Decisions
- **YYYY-MM-DD**: [Initial proposal notes or thoughts]
- **YYYY-MM-DD**: [Subsequent design meeting notes, review results, or denial reasoning]
```

---

## Optimizations Log

<!-- Append filled templates below this line -->
