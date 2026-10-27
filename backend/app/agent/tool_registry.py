"""
Registre de Tools pour l'Agent SIKA

Permet d'enregistrer, d'exposer et d'exécuter de manière sécurisée les fonctions Python sous forme de Tools.
"""

from typing import Dict, Callable, Any, List, Optional
import inspect
import logging
from .tools.tool_models import RiskLevel, ToolResult, ToolDefinition

logger = logging.getLogger("SikaToolRegistry")

class SikaToolRegistry:
    """Registre central des tools de l'agent SIKA."""

    def __init__(self):
        self._tools: Dict[str, Callable] = {}
        self._definitions: Dict[str, ToolDefinition] = {}
        self._register_default_tools()

    def _register_default_tools(self):
        """Enregistre les tools financiers SIKA par défaut."""
        from .tools import register_all_sika_tools
        register_all_sika_tools(self)

    def register(self, func: Callable, name: str, description: str, risk_level: RiskLevel = RiskLevel.READ_ONLY, input_schema: dict = None, output_schema: dict = None,
                 agent_exposed: bool = True):
        """Enregistre un tool avec sa définition et son niveau de risque."""
        self._tools[name] = func
        self._definitions[name] = ToolDefinition(
            name=name,
            description=description,
            risk_level=risk_level,
            input_schema=input_schema or {},
            output_schema=output_schema or {},
            agent_exposed=agent_exposed,
        )
        logger.info(f"[SIKA REGISTRY] Tool enregistré: {name} (Risque: {risk_level.value})")

    def get(self, name: str) -> Optional[Callable]:
        """Récupère la fonction d'un tool par son nom."""
        return self._tools.get(name)

    def get_definition(self, name: str) -> Optional[ToolDefinition]:
        """Récupère la définition d'un tool."""
        return self._definitions.get(name)

    def list_tools(self) -> List[Dict[str, Any]]:
        """Liste tous les tools disponibles avec leurs métadonnées."""
        return [def_item.dict() for def_item in self._definitions.values()]

    def exists(self, name: str) -> bool:
        """Vérifie si un tool existe dans le registre."""
        return name in self._tools

    def execute(self, name: str, arguments: Optional[Dict[str, Any]] = None, user_confirmed: bool = False) -> ToolResult:
        """
        Exécute un tool de manière sécurisée en validant les arguments et les permissions de risque.
        """
        if not self.exists(name):
            return ToolResult(
                success=False,
                tool_name=name,
                risk_level=RiskLevel.READ_ONLY,
                data={},
                error_message=f"Tool '{name}' inexistant dans le registre."
            )

        func = self._tools[name]
        tool_def = self._definitions[name]
        args = arguments or {}

        # 1. Vérification de la signature des arguments
        sig = inspect.signature(func)
        try:
            bound_args = sig.bind(**args)
            bound_args.apply_defaults()
        except TypeError as e:
            return ToolResult(
                success=False,
                tool_name=name,
                risk_level=tool_def.risk_level,
                data={},
                error_message=f"Arguments invalides pour '{name}': {e}"
            )

        # 2. Vérification de sécurité Human-in-the-loop
        if tool_def.risk_level in [RiskLevel.CONFIRMATION_REQUIRED, RiskLevel.EXECUTION] and not user_confirmed and name == "confirm_transfer":
            return ToolResult(
                success=False,
                tool_name=name,
                risk_level=tool_def.risk_level,
                requires_confirmation=True,
                data={"status": "confirmation_required"},
                error_message="L'action nécessite une confirmation humaine préalable."
            )

        # 3. Exécution
        try:
            result = func(*bound_args.args, **bound_args.kwargs)
            if isinstance(result, ToolResult):
                return result
            return ToolResult(
                success=True,
                tool_name=name,
                risk_level=tool_def.risk_level,
                data=result if isinstance(result, dict) else {"result": result}
            )
        except Exception as e:
            logger.error(f"Erreur lors de l'exécution du tool '{name}': {e}")
            return ToolResult(
                success=False,
                tool_name=name,
                risk_level=tool_def.risk_level,
                data={},
                error_message=f"Erreur interne lors de l'exécution du tool: {e}"
            )

    def agent_tool_names(self, exclude: Optional[set] = None) -> List[str]:
        """Noms des tools que le modèle IA a le droit d'appeler.

        Jamais EXECUTION ; jamais les outils de maintenance internes ; jamais ceux exclus pour cette requête
        (par exemple la confirmation par l'agent quand l'utilisateur ne l'a pas autorisée).
        """
        names = []
        for name, def_item in self._definitions.items():
            if exclude and name in exclude:
                continue
            if def_item.risk_level not in [RiskLevel.READ_ONLY, RiskLevel.CONFIRMATION_REQUIRED]:
                continue
            if not def_item.agent_exposed:
                continue
            names.append(name)
        return names

    def get_gemini_tools(self, exclude: Optional[set] = None) -> list:
        """Returns the tools safe for Gemini (READ_ONLY and CONFIRMATION_REQUIRED).

        Les tools disposant d'un input_schema explicite sont exposés sous forme de
        FunctionDeclaration stricte (le modèle ne voit jamais `user_id`) ; les autres
        restent des callables (comportement historique).
        """
        safe_tools = []
        declarations = []
        for name in self.agent_tool_names(exclude):
            def_item = self._definitions[name]
            if def_item.input_schema:
                declarations.append({
                    "name": name,
                    "description": def_item.description,
                    "parameters": def_item.input_schema,
                })
            else:
                safe_tools.append(self._tools[name])
        if declarations:
            try:
                from google.genai import types
                safe_tools.append(types.Tool(function_declarations=[types.FunctionDeclaration(**d) for d in declarations]))
            except Exception as e:  # SDK absent : les déclarations ne peuvent pas être construites
                logger.warning(f"[SIKA REGISTRY] FunctionDeclaration indisponible: {e}")
        return safe_tools

# Instance globale du registre
tool_registry = SikaToolRegistry()

