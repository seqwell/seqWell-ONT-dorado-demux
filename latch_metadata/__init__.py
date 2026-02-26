
from dataclasses import dataclass

from latch.types.metadata import (
    LatchAuthor,
    NextflowMetadata,
    NextflowParameter,
    NextflowRuntimeResources
)
from latch.types.directory import LatchDir

from .generated import NextflowSchemaArgsType, generated_flow


@dataclass
class WorkflowArgsType(NextflowSchemaArgsType):
    # add any custom parameters here
    ...


NextflowMetadata(
    display_name='seqWell ONT Dorado Demux',
    author=LatchAuthor(
        name="seqWell",
    ),
    parameters={
        "args": NextflowParameter(type=WorkflowArgsType)
    },
    runtime_resources=NextflowRuntimeResources(
        cpus=4,
        memory=8,
        storage_gib=100,
    ),
    log_dir=LatchDir("latch:///your_log_dir"),
    flow=generated_flow,
)
