from pathlib import Path
from rapid_elastic import pipeline
from cumulus_library_pcx.tools import filetool, settings

def main() -> list[Path]:
    query_topics = filetool.path_spreadsheet('query_topics.tsv')
    output_base = settings.get_elastic_output_dir().resolve()
    print('Configured output:', output_base)
    return pipeline.pipe_batch(query_topics=query_topics,
                               output_base=str(output_base))

if __name__ == '__main__':
    for csv_list in main():
        print(csv_list)
