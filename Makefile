SRC_DATA_PIPELINE = "data_pipeline"

all:
	echo "Nothing here yet."

.PHONY: dbt_compile dev extract_load deploy_models deploy_analytics

# TODO - remove this, do not depend on manifest.json
dbt_compile:
	cd $(SRC_DATA_PIPELINE) && dbt compile --profiles-dir profile --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET

dev:
	# Create virtualenv
	# Freeze to 3.10 because higher versions are not yet supported by underlying tools
	python3.10 -m venv .venv_el --upgrade-deps
	# Install Meltano and required plugins
	.venv_el/bin/pip3 install -r $(SRC_DATA_PIPELINE)/requirements-meltano.txt
	.venv_el/bin/meltano --cwd $(SRC_DATA_PIPELINE) install
	# dbt must be installed to separate venv, there are conflicts with what Meltano needs
	python3.10 -m venv .venv_t --upgrade-deps
	# Install dbt and required plugins
	.venv_t/bin/pip3 install -r $(SRC_DATA_PIPELINE)/requirements-dbt.txt
	.venv_t/bin/dbt deps --project-dir $(SRC_DATA_PIPELINE) --profiles-dir $(SRC_DATA_PIPELINE)/profile
	# Install dbt-gooddata plugin and related dependencies
	.venv_t/bin/pip3 install -r $(SRC_DATA_PIPELINE)/requirements-gooddata.txt
	# Real-time demo
	python3.10 -m venv .venv_rt --upgrade-deps
	# Install Meltano and required plugins
	.venv_el/bin/pip3 install -r $(SRC_DATA_PIPELINE)/requirements-real-time.txt


extract_load:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_GITHUB && meltano --environment $$ELT_ENVIRONMENT run tap-github-repo $$MELTANO_TARGET tap-github-org $$MELTANO_TARGET $$FR
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_FAA && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-faa $$MELTANO_TARGET $$FR
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_ECOMMERCE_DEMO && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-ecommerce-demo $$MELTANO_TARGET $$FR
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_DATA_SCIENCE && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-data-science $$MELTANO_TARGET $$FR
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_JIRA && meltano --environment $$ELT_ENVIRONMENT run tap-jira $$MELTANO_TARGET $$FR

extract_load_github:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_GITHUB && meltano --environment $$ELT_ENVIRONMENT run tap-github-repo $$MELTANO_TARGET tap-github-org $$MELTANO_TARGET $$FR

extract_load_faa:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_FAA && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-faa $$MELTANO_TARGET $$FR

extract_load_ecommerce_demo:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_ECOMMERCE_DEMO && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-ecommerce-demo $$MELTANO_TARGET $$FR

extract_load_data_science:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_DATA_SCIENCE && meltano --environment $$ELT_ENVIRONMENT run tap-s3-csv-data-science $$MELTANO_TARGET $$FR

extract_load_jira:
	cd $(SRC_DATA_PIPELINE) && export TARGET_SCHEMA=$$INPUT_SCHEMA_JIRA && meltano --environment $$ELT_ENVIRONMENT run tap-jira $$MELTANO_TARGET $$FR

transform:
	cd $(SRC_DATA_PIPELINE) && dbt run --profiles-dir profile --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$FR
	cd $(SRC_DATA_PIPELINE) && dbt test --profiles-dir profile --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET

transform_cloud:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt dbt_cloud_run --profiles-dir profile_cloud --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

transform_cloud_stats:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt dbt_cloud_stats --profiles-dir profile_cloud --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

invalidate_caches:
	# Invalidate GoodData caches after new data are delivered
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt upload_notification --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$DR

deploy_models: dbt_compile
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR provision_workspaces
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR register_data_sources --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR deploy_ldm --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

provision_workspaces:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR provision_workspaces

register_data_sources:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR register_data_sources --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

deploy_ldm: dbt_compile
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR deploy_ldm --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

deploy_models_cloud:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR provision_workspaces
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR register_data_sources --profiles-dir profile_cloud --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR deploy_ldm --profiles-dir profile_cloud --profile $$ELT_ENVIRONMENT --target $$DBT_TARGET $$GOODDATA_UPPER_CASE

deploy_and_test_analytics:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR deploy_analytics $$GOODDATA_UPPER_CASE
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR test_visualizations

deploy_analytics:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR deploy_analytics $$GOODDATA_UPPER_CASE

store_analytics:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt store_analytics

test_visualizations:
	cd $(SRC_DATA_PIPELINE) && gooddata-dbt $$DR test_visualizations
