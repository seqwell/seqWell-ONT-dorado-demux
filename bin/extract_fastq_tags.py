#!/usr/bin/env python3
"""
extract_fastq_tags.py  <input.fastq[.gz]>  <output.tsv>

Parses Dorado FASTQ headers and writes the metadata as SAM-format tags to a
UUID-keyed TSV, used by reheader_reads.py to restore header metadata after
dorado demux strips it.

Input may be gzipped or plain FASTQ (detected by magic bytes, not extension).

Dorado FASTQ header format:
  @<uuid> runid=X read=N ch=N start_time=T flow_cell_id=X ...

Output TSV (one line per read):
  <uuid>\t <tag> <tag> ...      e.g.  <uuid>\t ch:i:123 rn:i:456 RG:Z:...

Only fields listed in FIELD_MAP are kept; all others are dropped.
"""
import gzip, sys, shutil, subprocess

fastq_path = sys.argv[1]
out_path   = sys.argv[2]

# Map Dorado FASTQ key=value fields to SAM tag equivalents
# key=value_field  →  (SAM_tag, SAM_type)
FIELD_MAP = {
    'ch':                      ('ch', 'i'),   # channel number
    'read':                    ('rn', 'i'),   # read number (rn is ONT convention)
    'start_time':              ('st', 'Z'),   # start time
    'flow_cell_id':            ('fn', 'Z'),   # flow cell ID
    'runid':                   ('RG', 'Z'),   # run ID → read group
    'barcode':                 ('BC', 'Z'),   # barcode if present
    'barcode_score':           ('bs', 'i'),   # barcode score
    'protocol_group_id':       ('px', 'Z'),   # protocol / experiment group ID
    'sample_id':               ('si', 'Z'),   # sample ID (kept as string; may be numeric)
    'parent_read_id':          ('pi', 'Z'),   # parent read UUID
    'basecall_model_version_id': ('bv', 'Z'), # basecall model version
}

def open_fastq(path):
    # detect gzip by magic bytes, not extension
    with open(path, 'rb') as f:
        is_gz = f.read(2) == b'\x1f\x8b'

    if not is_gz:
        return open(path, 'rb'), None          # plain FASTQ

    if shutil.which('pigz'):
        proc = subprocess.Popen(['pigz', '-dc', '-p', '2', path],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        return proc.stdout, proc
    return gzip.open(path, 'rb'), None

written = 0
fh, proc = open_fastq(fastq_path)
with open(out_path, 'w') as out:
    while True:
        h = fh.readline()
        if not h:
            break
        fh.readline(); fh.readline(); fh.readline()  # skip seq, +, qual
        h = h.decode() if isinstance(h, bytes) else h
        h = h.rstrip()
        if not h.startswith('@'):
            continue
        body = h[1:]
        parts = body.split()
        if not parts:
            continue
        uuid = parts[0]
        sam_tags = []
        for field in parts[1:]:
            if '=' not in field:
                continue
            k, _, v = field.partition('=')
            if k not in FIELD_MAP:
                continue
            sam_key, sam_type = FIELD_MAP[k]
            if sam_type == 'i':
                try:
                    sam_tags.append(f"{sam_key}:i:{int(v)}")
                except ValueError:
                    # fall back to string tag if value isn't a clean integer
                    sam_tags.append(f"{sam_key}:Z:{v}")
            else:
                sam_tags.append(f"{sam_key}:Z:{v}")
        tags_str = ' '.join(sam_tags)
        # Same leading-space-after-tab convention as extract_bam_tags.py
        out.write(f"{uuid}\t {tags_str}\n")
        written += 1

if proc:
    proc.wait()
print(f"[extract_fastq_tags] Wrote {written} entries to {out_path}", file=sys.stderr)
