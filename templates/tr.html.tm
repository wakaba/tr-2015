<html t:params="$app">
<t:include path=_macro.html.tm />
<t:call x="use Wanage::URL">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section id=github>
  <h1>GitHub リポジトリー</h1>

  <form action=/account/login method=post class=login>
    <input type=hidden name=server value=github>
    <button type=submit>GitHub アカウントでログイン</button>
  </form>

  <p><button type=button onclick=" loadGitHubList (true) ">更新</button>
  <ul class=repos>
  </ul>
  <template class=repo-template>
    <a data-href="/tr/{url}/{branch}/{path}/">{label}</a>
    <p class=desc>{desc}
  </template>
  <script>
    function loadGitHubList (update) {
      var ghSection = document.querySelector ('#github');
      var xhr = new XMLHttpRequest;
      xhr.open ('GET', '/remote/github/repos.json' + (update ? '?update=1' : ''), true);
      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            var json = JSON.parse (xhr.responseText);
            var repos = ghSection.querySelector ('.repos');
            repos.textContent = '';
            var repoTemplate = ghSection.querySelector ('.repo-template');
            var keys = [];
            for (var key in json.repos) {
              keys.push (key);
            }
            keys = keys.sort (function (a, b) { return a < b ? -1 : +1 });
            keys.forEach (function (key) {
              var repo = json.repos[key];
              var li = document.createElement ('li');
              li.innerHTML = repoTemplate.innerHTML;
              var a = li.querySelector ('a');
              a.href = a.getAttribute ('data-href')
                  .replace (/\{url\}/g, encodeURIComponent (repo.url))
                  .replace (/\{branch\}/g, encodeURIComponent (repo.default_branch))
                  .replace (/\{path\}/g, encodeURIComponent ('/'));
              a.textContent = repo.label;
              li.querySelector ('.desc').textContent = repo.desc;
              repos.appendChild (li);
            }); // repo
          } else {
            // XXX
          }
        }
      };
      xhr.send (null);
    } // loadGitHubList
    loadGitHubList (false);
  </script>
</section>

<t:include path=_footer.html.tm />
<script src=/js/time.js />
<script> new TER (document.body) </script>
