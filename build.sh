#!/bin/bash
set -ex

# initialize and update submodules
git submodule update --init --recursive
git submodule update --remote

# build the ontology and publish the generated Turtle files:
#   /watr.ttl            unversioned "latest"
#   /watr-<version>.ttl  immutable versioned snapshot
# (PR #45: sources moved to ontology/, build output now lands in build/)
# recreate the ontoenv environment if it predates the water/ -> ontology/ rename
rm -rf water-ontology/.ontoenv
make -C water-ontology build-ontology
cp water-ontology/build/watr.ttl watr.ttl
VERSIONED_TTL_FILE=$(basename "$(ls water-ontology/build/watr-*.ttl | head -n1)")
VERSIONED_TTL_VERSION=${VERSIONED_TTL_FILE#watr-}
VERSIONED_TTL_VERSION=${VERSIONED_TTL_VERSION%.ttl}
cp "water-ontology/build/${VERSIONED_TTL_FILE}" "${VERSIONED_TTL_FILE}"
cp watr.ttl watr-ontology-browser/ontologies/watr.ttl

# update placeholders in index.template and save it as index.html
LAST_UPDATED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
WATER_TTL_LAST_UPDATED=$(date -u -r water-ontology/build/watr.ttl +"%Y-%m-%d %H:%M:%S UTC")
sed \
    -e "s/WATER_TTL_UPDATED_AT/$WATER_TTL_LAST_UPDATED/g" \
    -e "s/LAST_UPDATED/$LAST_UPDATED/g" \
    -e "s/VERSIONED_TTL_VERSION/$VERSIONED_TTL_VERSION/g" \
    -e "s/VERSIONED_TTL_FILE/$VERSIONED_TTL_FILE/g" \
    index.template > index.html

# create build directory
rm -rf build
mkdir -p build

# copy top-level site files into build/
cp index.html build/
cp CNAME build/
cp watr.ttl build/
cp "${VERSIONED_TTL_FILE}" build/

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
BASE_URL="/docs" uv run --project ../../water-ontology jupyter-book build .
cd ../..

# move built HTML to build/docs
mv _staging/water-ontology/_build/html build/docs

# build acquirium docs (jupyter-book) into build/acquirium
# content comes from the acquirium submodule; config lives in acquirium-docs/
rm -rf _staging/acquirium
mkdir -p _staging/acquirium
cp -r acquirium/docs/* _staging/acquirium/
cp acquirium-docs/_config.yml acquirium-docs/_toc.yml _staging/acquirium/
uv run --project water-ontology jupyter-book build _staging/acquirium
mv _staging/acquirium/_build/html build/acquirium
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
npx rdf add file "https://watermetadata.org/ontology/watr" vocab/watr.ttl
npx rdf add file "http://qudt.org/2.1/vocab/unit" vocab/VOCAB_QUDT-UNITS-ALL.ttl
npx rdf add file "http://qudt.org/2.1/vocab/quantitykind" vocab/VOCAB_QUDT-QUANTITY-KINDS-ALL.ttl
npx rdf add file "http://www.w3.org/ns/shacl" vocab/shacl.ttl
npx rdf add file "https://brickschema.org/schema/Brick/ref" vocab/ref-schema.ttl
npx rdf make site --output "${ROOTDIR}/build/ontology" --base /ontology/
cd "${ROOTDIR}"
rm -rf /tmp/rdf-toolkit
