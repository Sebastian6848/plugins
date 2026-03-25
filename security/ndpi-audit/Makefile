PLUGIN_NAME=        ndpi-audit
PLUGIN_VERSION=     1.0
PLUGIN_COMMENT=     Application identification audit based on nDPI mirror mode
PLUGIN_MAINTAINER=  xwy@example.com

selfcheck-package:
	@echo "[ndpi-audit] self-check package manifest/plist"
	@plist_file="$$(mktemp)"; \
		${MAKE} -C ${.CURDIR} plist > "$${plist_file}"; \
		for required in \
			"/usr/local/bin/ndpiReader" \
			"/usr/local/share/ndpi/ja4_fingerprints.csv" \
			"/usr/local/share/ndpi/tcp_fingerprints.csv" \
			"/usr/local/share/ndpi/protos.txt" \
			"/usr/local/share/ndpi/sha1_fingerprints.csv" \
			"/usr/local/share/ndpi/categories.txt"; do \
			grep -qx "$${required}" "$${plist_file}" || { \
				echo "[FAIL] missing in plist: $${required}"; \
				rm -f "$${plist_file}"; \
				exit 1; \
			}; \
		done; \
		rm -f "$${plist_file}"; \
		echo "[OK] all bundled engine/data files exist in plist"

selfcheck-stage:
	@echo "[ndpi-audit] self-check staged install"
	@stage_dir="$$(mktemp -d)"; \
		${MAKE} -C ${.CURDIR} DESTDIR="$${stage_dir}" install > /dev/null; \
		test -x "$${stage_dir}/usr/local/bin/ndpiReader" || { \
			echo "[FAIL] staged binary missing or not executable"; \
			rm -rf "$${stage_dir}"; \
			exit 1; \
		}; \
		for required in \
			"$${stage_dir}/usr/local/share/ndpi/ja4_fingerprints.csv" \
			"$${stage_dir}/usr/local/share/ndpi/tcp_fingerprints.csv" \
			"$${stage_dir}/usr/local/share/ndpi/protos.txt" \
			"$${stage_dir}/usr/local/share/ndpi/sha1_fingerprints.csv" \
			"$${stage_dir}/usr/local/share/ndpi/categories.txt"; do \
			test -f "$${required}" || { \
				echo "[FAIL] staged data file missing: $${required}"; \
				rm -rf "$${stage_dir}"; \
				exit 1; \
			}; \
		done; \
		rm -rf "$${stage_dir}"; \
		echo "[OK] staged files and permissions validated"

selfcheck: selfcheck-package selfcheck-stage

.include "../../Mk/plugins.mk"
