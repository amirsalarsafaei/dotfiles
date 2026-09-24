{
  pkgs,
  dataScience ? false,
}:
pkgs.python3.withPackages (
  ps:
  [
    ps.ipython
    ps.pytest
    ps.numpy
    ps.pandas
    ps.pillow
    ps.scipy
    ps.matplotlib
    ps.seaborn
    ps.requests
    ps.httpx
    ps.beautifulsoup4
    ps.lxml
    ps.openpyxl
    ps.pyarrow
    ps.pyyaml
    ps.rich
    ps.tabulate
    ps.pypdf
    ps.pymupdf
    ps.python-docx
    ps.python-pptx
  ]
  ++ pkgs.lib.optionals dataScience [
    ps.jupyterlab
    ps.notebook
    ps.ipykernel
    ps.scikit-learn
  ]
)
