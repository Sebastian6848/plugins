PLUGIN_NAME=		anti-virus
PLUGIN_VERSION=		1.0.0
PLUGIN_COMMENT=		Integrated Antivirus (Squid + c-icap + ClamAV)
PLUGIN_DEPENDS=		os-squid clamav c-icap c-icap-modules
PLUGIN_MAINTAINER=	maintainer@example.com

MSGFMT?=		msgfmt
LOCALE_DIR=		${.CURDIR}/src/opnsense/mvc/app/locale

build:
	@for lang in en_US zh_CN; do \
		po="${LOCALE_DIR}/$${lang}/LC_MESSAGES/OPNsense.Antivirus.po"; \
		mo="${LOCALE_DIR}/$${lang}/LC_MESSAGES/OPNsense.Antivirus.mo"; \
		if command -v ${MSGFMT} >/dev/null 2>&1; then \
			${MSGFMT} -o "$${mo}" "$${po}"; \
		else \
			echo "msgfmt not found, skipping $${mo}"; \
		fi; \
	done

.include "../../Mk/plugins.mk"
