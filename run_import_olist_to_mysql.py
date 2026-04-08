from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


def load_and_run():
    script_path = Path(__file__).resolve().parent / "format" / "import_olist_to_mysql.py"
    spec = spec_from_file_location("import_olist_to_mysql", script_path)
    module = module_from_spec(spec)
    if spec.loader is None:
        raise RuntimeError(f"Unable to load script: {script_path}")
    spec.loader.exec_module(module)
    module.main()


if __name__ == "__main__":
    load_and_run()
