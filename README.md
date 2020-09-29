

# small trick, we move the pdf.js-gh-pages dir into a webcomponent dir
webcomponents: pdf.js-gh-pages.zip
	unzip pdf.js-gh-pages.zip
	rm -rf webcomponents
	mv pdf.js-gh-pages webcomponents
	rm -rf webcomponents/web 
	rm -rf webcomponents/build
	mv webcomponents/es5/web webcomponents/web
	mv webcomponents/es5/build webcomponents/build

# download the distrib
pdf.js-gh-pages.zip:
	curl -L -c cookie.txt https://github.com/mozilla/pdf.js/archive/gh-pages.zip >$@

# we use the original viewer page and inject our gICAPI boiler plate script
webcomponents/web/web.html: webcomponents webcomponents/web/viewer.html
	cp webcomponents/web/viewer.html webcomponents/web/web.html
	patch -p0 <web3.patch
	cp myGICAPI.js webcomponents/web

fglwebrun:
	git clone https://github.com/FourjsGenero/tool_fglwebrun.git fglwebrun

webrun: all fglwebrun download_and_patch
	fglwebrun/fglwebrun pdfjs

