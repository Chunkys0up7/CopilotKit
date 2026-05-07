"""CoAgent definitions.

Agents go here. Each agent is a single-file module exposing a `build()`
function that returns the agent object the runtime knows how to host
(LangGraph `StateGraph`, CrewAI `Crew`, etc.).

Empty by default — see `docs/classes/CoAgent.md` for the contract and
the demo agent template in `demo_agent.py`.
"""

from .demo_agent import build_demo_agent

__all__ = ["build_demo_agent"]
