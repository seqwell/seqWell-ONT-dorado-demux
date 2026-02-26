# This file is auto-generated, PLEASE DO NOT EDIT DIRECTLY! To update, run
#
#   $ latch generate-metadata --nextflow nextflow_schema.json
#
# Add any custom logic or parameters in `latch_metadata/__init__.py`.

import typing
from dataclasses import dataclass, field
from enum import Enum

import typing_extensions
from flytekit.core.annotation import FlyteAnnotation

from latch.ldata.path import LPath
from latch.types.directory import LatchDir
from latch.types.file import LatchFile
from latch.types.metadata import Params, Section, Spoiler, Text
from latch.types.samplesheet_item import SamplesheetItem



@dataclass
class NextflowSchemaArgsType:
    input: typing_extensions.Annotated[str, FlyteAnnotation({'display_name': 'Input', 'default': None, 'samplesheet': False, 'output': False, 'required': True, 'description': 'Path to input FASTQ file(s) using glob pattern, e.g. --input "path/to/fastq_pass/*.fastq.gz"'})]
    outdir: typing_extensions.Annotated[LatchDir, FlyteAnnotation({'display_name': 'Outdir', 'default': None, 'samplesheet': False, 'output': True, 'required': True, 'description': 'Output directory.'})]
    pool_ID: typing_extensions.Annotated[str, FlyteAnnotation({'display_name': 'Pool Id', 'default': None, 'samplesheet': False, 'output': False, 'required': True, 'description': 'Pool identifier.'})]
    barcodes: typing_extensions.Annotated[typing.Optional[LatchFile], FlyteAnnotation({'display_name': 'Barcodes', 'default': {'scalar': {'union': {'value': {'scalar': {'blob': {'metadata': {'type': {}}}}}, 'type': {'blob': {}, 'structure': {'tag': 'LatchFilePath'}}}}}, 'samplesheet': False, 'output': False, 'required': False, 'description': 'Path to barcode file, e.g. --barcodes barcode.fa'})] = field(default_factory=lambda: LatchFile('assets/barcodes.384.fa'))
    arrangement_toml: typing_extensions.Annotated[typing.Optional[LatchFile], FlyteAnnotation({'display_name': 'Arrangement Toml', 'default': {'scalar': {'union': {'value': {'scalar': {'blob': {'metadata': {'type': {}}}}}, 'type': {'blob': {}, 'structure': {'tag': 'LatchFilePath'}}}}}, 'samplesheet': False, 'output': False, 'required': False, 'description': 'Path to arrangement TOML configuration file.'})] = field(default_factory=lambda: LatchFile('assets/arrangement.toml'))
    length_filter: typing_extensions.Annotated[typing.Optional[int], FlyteAnnotation({'display_name': 'Length Filter', 'default': {'scalar': {'union': {'value': {'scalar': {'primitive': {'integer': '150'}}}, 'type': {'simple': 'INTEGER', 'structure': {'tag': 'int'}}}}}, 'samplesheet': False, 'output': False, 'required': False, 'description': 'Minimum read length filter.'})] = field(default=150)
    error_rate: typing_extensions.Annotated[typing.Optional[float], FlyteAnnotation({'display_name': 'Error Rate', 'default': {'scalar': {'union': {'value': {'scalar': {'primitive': {'floatValue': 0.12}}}, 'type': {'simple': 'FLOAT', 'structure': {'tag': 'float'}}}}}, 'samplesheet': False, 'output': False, 'required': False, 'description': 'Maximum allowed error rate for demultiplexing.'})] = field(default=0.12)





generated_flow = [Section('Input & Output Options', Text('Define the input and output data locations.'), Params('input', 'outdir', 'pool_ID')), Spoiler('Demultiplexing Options', Text('Options for demultiplexing configuration.'), Params('barcodes', 'arrangement_toml', 'length_filter', 'error_rate'))]
