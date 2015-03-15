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

  <!-- XXX <p><button type=button>更新</button>-->
  <ul class=repos>
  </ul>
  <template class=repo-template>
    <a data-href="/tr/{url}/{branch}/{path}/">{label}</a>
    <p class=desc>{desc}
  </template>
  <script>
    var ghSection = document.querySelector ('#github');
    var xhr = new XMLHttpRequest;
    xhr.open ('GET', '/remote/github/repos.json', true);
    xhr.onreadystatechange = function () {
      if (xhr.readyState === 4) {
        if (xhr.status === 200) {
          var json = JSON.parse (xhr.responseText);
          var repos = ghSection.querySelector ('.repos');
          repos.textContent = '';
          var repoTemplate = ghSection.querySelector ('.repo-template');
          for (var key in json.repos) {
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
          } // repo
        } else {
          // XXX
        }
      }
    };
    xhr.send (null);
  </script>
</section>

<t:include path=_footer.html.tm />
<script src=/js/time.js />
<script> new TER (document.body) </script>
