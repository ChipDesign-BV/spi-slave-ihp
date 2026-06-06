PDK_ROOT ?= /opt/ihp
PDK ?= ihp-sg13g2

export PDK_ROOT PDK

librelane:
	bash -lc 'source ihp_pdk.env && librelane config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk'
.PHONY: librelane

librelane-openroad:
	bash -lc 'source ihp_pdk.env && librelane config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInOpenROAD'
.PHONY: librelane-openroad
