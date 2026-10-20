# Synchronous FIFO (Verilog)

Parameterized (`DATA_W`, `DEPTH`) synchronous FIFO.

**Concepts:** read/write pointers with wraparound · occupancy counter · full/empty flags · overflow/underflow protection · simultaneous read/write.

| Case | Behaviour |
|---|---|
| Write when full | Ignored (no data corruption) |
| Read when empty | Ignored |
| Read + write together | Both happen, count unchanged |
| Read + write when full / empty | Only the legal one happens |

## Run (Icarus Verilog)
```
iverilog -g2005 -o sim tb/tb_sync_fifo.v rtl/sync_fifo.v && vvp sim
```
Expected: `RESULT: PASS`

## Verification
Self-checking testbench with a cycle-accurate reference model comparing read data, `count`, `full`, `empty` each cycle. Tests: fill/overflow, drain/underflow, simultaneous r/w at full, empty and steady state, pointer wraparound, 2000 cycles of random traffic.

```
rtl/sync_fifo.v      design
tb/tb_sync_fifo.v    testbench
```
