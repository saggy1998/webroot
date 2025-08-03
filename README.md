# simple webroot

Install Github Desktop

Fork and clone the [modelearth/webroot](https://github.com/modelearth/webroot/)

Choose "contribute to parent repo"

Right-click on "webroot" choose "Open in Terminal", and start a virtual environment with Claude Code CLI.

MacOS

	python3 -m venv env
	source env/bin/activate
	npx @anthropic-ai/claude-code

WindowsOS (first time)

<!-- Not sure yet if .bat will be there for all Windows usage. -->

	python -m venv env && env\Scripts\activate.bat && npx @anthropic-ai/claude-code

Install Node.js if this https://nodejs.org/

	npx @anthropic-ai/claude-code

WindowsOS (subsequent times)

	python -m venv env && env\Scripts\activate.bat && npx @anthropic-ai/claude-code


Run the following in your local "webroot" folder to start an http server on port 8880

	start server

Or

	python -m http.server 8880

Then view pages at:

[localhost:8880/](http://localhost:8880/)  
[localhost:8880/team](http://localhost:8880/team/)  
[localhost:8880/home](http://localhost:8880/home/)  
[localhost:8880/localsite](http://localhost:8880/comparison/)  
[localhost:8880/localsite](http://localhost:8880/localsite/)  
[localhost:8880/feed](http://localhost:8880/feed/)  


Also look at your code with an editor like VS Code.