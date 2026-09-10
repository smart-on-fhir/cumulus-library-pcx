"""Generate JSON schemas for the PCX extraction and document-routing tasks."""
import importlib
import json
from pathlib import Path

BASE_DIR = Path(__file__).parent
TASK_MODELS = {
    "diagnosis": "PcxDiagnosisAnnotation",
    "surgery": "PcxSurgeryAnnotation",
    "radiation": "PcxRadiationAnnotation",
    "systemic_therapy": "PcxSystemicTherapyAnnotation",
    "metastasis": "PcxMetastasisAnnotation",
    "molecular": "PcxMolecularAnnotation",
    "response": "PcxResponseAnnotation",
    "event": "PcxEventAnnotation",
    "patient": "PcxPatientTimelineAnnotation",
    "laboratory": "PcxLaboratoryAnnotation",
    "predisposition": "PcxPredispositionAnnotation",
    "registry_eligibility": "PcxTrialEligibilityAnnotation",
    "medulloblastoma": "PcxMedulloblastomaAnnotation",
    "transition_of_care": "PcxTransitionOfCareAnnotation",
    "document_type": "DocumentTypeAnnotation",
    "document_topic": "DocumentTopicAnnotation",
}


def create(annotation, filename: str, output_dir: Path | None = None) -> Path:
    """Write a Pydantic annotation schema, creating the destination directory."""
    directory = Path(output_dir) if output_dir is not None else BASE_DIR / "schemas"
    directory.mkdir(parents=True, exist_ok=True)
    file_path = directory / filename
    file_path.write_text(json.dumps(annotation.model_json_schema(), indent=2) + "\n", encoding="utf-8")
    return file_path


def create_pcx_llm_study_variables(output_dir: Path | None = None) -> list[Path]:
    """Generate one schema per PCX task, including document routing."""
    paths = []
    for task, class_name in TASK_MODELS.items():
        module = importlib.import_module(f"cumulus_library_pcx.llm.models.{task}")
        paths.append(create(
            getattr(module, class_name),
            f"pcx-{task.replace('_', '-')}-annotation.json",
            output_dir,
        ))
    return paths


if __name__ == "__main__":
    for path in create_pcx_llm_study_variables():
        print(path)
