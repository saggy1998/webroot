# simple webroot

First start a virtual environment with Claude Code CLI in the modelearth folder.

MacOS

	python3 -m venv env
	source env/bin/activate
	npx @anthropic-ai/claude-code

WindowsOS

	python -m venv env
	env\Scripts\activate
	npx @anthropic-ai/claude-code



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