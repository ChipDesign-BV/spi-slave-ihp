PDK_ROOT ?= /foss/pdks
PDK ?= ihp-sg13g2

export PDK_ROOT PDK

librelane:
	bash -lc 'source ihp_pdk.env && librelane config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk'
.PHONY: librelane
