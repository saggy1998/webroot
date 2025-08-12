Run the following in your local "webroot" folder using Claude to start an http server on port 8887:

	start server

Or run without Claude.:

	python -m http.server 8887

Then view pages at:

[localhost:8887/](http://localhost:8887/)  
[localhost:8887/team](http://localhost:8887/team/)  
[localhost:8887/comparison](http://localhost:8887/comparison/)  
[localhost:8887/realitystream](http://localhost:8887/realitystream/)  
[localhost:8887/localsite](http://localhost:8887/localsite/)  
[localhost:8887/home](http://localhost:8887/home/)  
[localhost:8887/feed](http://localhost:8887/feed/)  

Look at the code in your webroot with an editor like [Sublime Text](https://www.sublimetext.com/) ($99), [VS Code](https://code.visualstudio.com/) or [WebStorm](https://www.jetbrains.com/webstorm/).

## Get Trade Flow Repos

To contribute to our trade flow visualizations for **Data Science**, run the following to fork and clone:  
[exiobase](https://github.com/ModelEarth/exiobase/tree/main/tradeflow), profile, useeio.js and io

	fork trade repos to [your github account]
	clone trade repos from [your github account]

The above requires having GitHub CLI (gh) installed locally and authenticated with your GitHub account.

[Overview of repos (codechat)](https://model.earth/codechat/)

## How to deploy changes

Update and make commits often (at least hourly).
Append nopr" or "No PR" if you are not yet ready to send a Pull Request.

Run "update" hourly to safely pull updates from the ModelEarth parent repositories.

When making any change, run "commit" to send a PR. This will also commit changes in submodules and forks.

	update
	commit

Addtional options:

	commit [folder name]  # commit a specific submodule or fork
	commit submodules  # commit changes from all submodules changed
	commit forks  # commit the 4 forks added for the trade flow


Or when changing a cloned repo, commit the specific repo using Github Desktop. Then submit a PR through the Github.com website.