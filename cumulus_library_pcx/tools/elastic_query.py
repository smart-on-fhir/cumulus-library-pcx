from pathlib import Path
from rapid_elastic import pipeline
from cumulus_library_pcx.tools import filetool

#-----------------------------------------------------------------------------
# you may need to manually install "rapid-elastic"
#
# python -m pip install --upgrade --force-reinstall \
#   "rapid-elastic @ git+ssh://git@github.com/smart-on-fhir/rapid-elastic.git@main"
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# make
#-----------------------------------------------------------------------------
def make() -> list[Path]:
    query_topics = filetool.path_spreadsheet('query_topics.tsv')
    return pipeline.pipe_batch(query_topics)

if __name__ == '__main__':
    for csv_list in make():
        print(csv_list)
