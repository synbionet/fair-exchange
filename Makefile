.PHONY: artifacts, deploy, clean-artifacts, analyze


clean-artifacts:
	rm -rf artifacts

artifacts: 
	mkdir -p artifacts
	##cp ./out/BionetRouter.sol/BionetRouter.json artifacts/BionetRouter.json
	##cp ./out/BionetVoucher.sol/BionetVoucher.json artifacts/BionetVoucher.json
	##cp ./out/BionetExchange.sol/BionetExchange.json artifacts/BionetExchange.json

deploy:
	forge script script/AnvilDeploy.s.sol:AnvilDeployScript --fork-url http://0.0.0.0:8545 --broadcast

analyze: 
	slither . --filter-path lib,tests,script  --foundry-out-directory build