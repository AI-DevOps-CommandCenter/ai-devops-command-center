"""Switchable faults and a simulated downstream dependency ("inventory").

A fault makes the dependency slow or failing. Opening the circuit breaker
stops calling the dependency, which is what the executor's circuit_breaker
action does. A restart clears everything because the state is in memory.
"""

import asyncio
import random
from dataclasses import dataclass


class DependencyError(Exception):
    """Raised by the simulated inventory dependency while an error fault is active."""


@dataclass
class FaultState:
    mode: str = "off"
    rate: float = 0.0
    breaker_open: bool = False

    def set_fault(self, mode: str, rate: float) -> None:
        self.mode = mode
        self.rate = 0.0 if mode == "off" else rate

    def hits(self, mode: str) -> bool:
        return self.mode == mode and random.random() < self.rate

    def snapshot(self) -> dict:
        return {"mode": self.mode, "rate": self.rate, "breaker_open": self.breaker_open}


async def call_inventory(faults: FaultState, latency_seconds: float) -> int:
    """Return a stock level, or fail or stall according to the active fault."""
    if faults.hits("latency"):
        await asyncio.sleep(latency_seconds)
    if faults.hits("errors"):
        raise DependencyError("inventory service returned 503")
    return random.randint(0, 50)
