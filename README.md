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

<div style="margin: 16px 0;">
  <a href="http://localhost:8887/team/admin/sql/panel/" class="btn btn-primary" style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; background-color: #3B82F6; color: white; text-decoration: none; border-radius: 6px; font-weight: 500; margin-right: 12px;">
    <span>🗄️</span>
    Rust API and Database
  </a>
</div>  

Look at the code in your webroot with an editor like [Sublime Text](https://www.sublimetext.com/) ($99), [VS Code](https://code.visualstudio.com/) or [WebStorm](https://www.jetbrains.com/webstorm/).

<div id="tradeFlowRepos"></div>

## How to deploy changes

Update and make commits often (at least hourly).
Append nopr" or "No PR" if you are not yet ready to send a Pull Request.

Run "pull" hourly to safely pull updates to the modelearth repos residing in your webroot

When making any change, run "push" to send a PR. "push" updates the webroot, submodules and forks.

	pull
	push

Addtional options:

	push [folder name]  # Deploy a specific submodule or fork
	push submodules  # Deploy changes from all submodules changed
	push forks  # Deploy the 4 forks added for the trade flow


Or when changing a cloned repo, commit the specific repo using Github Desktop. 
Then submit a PR through the Github.com website.