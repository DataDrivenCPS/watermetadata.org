#!/bin/bash
set -e

# update LAST_UPDATED in index.template to current date in format YYYY-MM-DD HH:MM:SS UTC
# and save it as index.html
LAST_UPDATED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
sed "s/LAST_UPDATED/$LAST_UPDATED/g" index.template > index.html

# initialize and update submodules
git submodule update --init --recursive

# create build directory
rm -rf build
mkdir -p build

# copy top-level site files into build/
cp index.html build/
cp CNAME build/

# build water-ontology jupyter book
# stage the docs content with our own myst.yml config
rm -rf _staging/water-ontology
mkdir -p _staging/water-ontology
cp -r water-ontology/docs/* _staging/water-ontology/
cp myst.yml _staging/water-ontology/

# install water-ontology project dependencies (ensures entry points are available)
uv sync --project water-ontology

# generate template library documentation (sphinx-autodoc-bmotif v0.2.0)
ROOTDIR=$(pwd)
uv run --project water-ontology --with sphinx-autodoc-bmotif sphinx-autodoc-bmotif generate \
    "${ROOTDIR}/water-ontology/libraries/templates" \
    "${ROOTDIR}/_staging/water-ontology/libraries"

# build with BASE_URL so links work at watermetadata.org/docs
cd _staging/water-ontology
BASE_URL="/docs" uv run --project ../../water-ontology jupyter-book build --html
cd ../..

# move built HTML to build/docs
mv _staging/water-ontology/_build/html build/docs
rm -rf _staging

# build watr-ontology-browser and copy to build/ontology
rm -rf /tmp/rdf-toolkit
git clone https://github.com/KrishnanN27/rdf-toolkit /tmp/rdf-toolkit
cp -r watr-ontology-browser/ontologies/* /tmp/rdf-toolkit/explorer/vocab/
cp watr-ontology-browser/rdfconfig.json /tmp/rdf-toolkit/explorer/
cd /tmp/rdf-toolkit
npm ci
npm run build
npm i @rdf-toolkit/cli
cd explorer
npx rdf add file "urn:nawi-water-ontology" vocab/water.ttl
npx rdf add file "http://qudt.org/2.1/vocab/unit" vocab/VOCAB_QUDT-UNITS-ALL.ttl
npx rdf add file "http://qudt.org/2.1/vocab/quantitykind" vocab/VOCAB_QUDT-QUANTITY-KINDS-ALL.ttl
npx rdf add file "http://www.w3.org/ns/shacl" vocab/shacl.ttl
npx rdf add file "https://brickschema.org/schema/Brick/ref" vocab/ref-schema.ttl
npx rdf make site --output "${ROOTDIR}/build/ontology" --base /ontology
cd "${ROOTDIR}"
rm -rf /tmp/rdf-toolkit
