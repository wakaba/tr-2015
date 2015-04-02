<html t:params="$app $repo_access_rows">
<t:include path=_macro.html.tm />
<t:call x="use Wanage::URL">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section class=repos>
  <h1>テキストリポジトリー</h1>

  <p><input type=search placeholder=絞り込み>
  <p><button type=button class=update-github>GitHub リポジトリー一覧を更新</button>

  <p class=status hidden><progress/> <span class=message>{status}</span>

  <table>
    <thead>
      <tr>
        <th>リポジトリー
        <th>表示
        <th>編集
        <th>管理
    </thead>
    <template class=repo-row-template data-true=&#x2714; data-false=- data-na>
      <td onclick=" this.querySelector ('a').click () ">
        <p><a href><strong class=label>{label}</strong></a>
        <p class=desc>{desc}
        <p class=join-actions>
          <button type=button class=as-translator>翻訳者として参加</button>
          <button type=button class=as-developer>開発者として参加</button>
          <button type=button class=as-owner>所有者として参加</button>
      <td><span class=scope-read>{boolean}</span>
      <td><span class=scope-edit>{boolean}</span>
      <td><span class=scope-repo>{boolean}</span>
    </template>
    <tbody>
  </table>
  <script src=/js/core.js charset=utf-8 />
  <script>
    (function () {
      var filterInput = document.querySelector ('.repos input[type=search]');
      var timer;
      filterInput.oninput = function () {
        clearTimeout (timer);
        timer = setTimeout (function () { updateReposTable () }, 100);
      };
    }) ();

    document.querySelector ('.repos .update-github').onclick = function () {
      var button = this;
      button.disabled = true;
      var status = document.querySelector ('.repos .status');
      showProgress ({init: true}, status);
      var fd = new FormData;
      fd.append ('operation', 'github');
      server ('POST', '/tr.ndjson', fd, function (res) {
        loadRepos ();
        status.hidden = true;
        button.disabled = false;
      }, function (json) {
        // XXX if guest or not linked
        showError (json, status);
        button.disabled = false;
      }, function (json) {
        showProgress (json, status);
      });
    }; // onclick

    function loadRepos () {
      var status = document.querySelector ('.repos .status');
      showProgress ({init: true, message: 'Loading...'}, status);
      server ('GET', '/tr.ndjson', null, function (res) {
        updateReposData (res.data);
        updateReposTable ();
        status.hidden = true;
      }, function (json) {
        showError (json, status);
      }, function (json) {
        showProgress (json, status);
      });
    }

    function updateReposData (json) {
      var repos = {};
      for (var key in json) {
        for (var url in json[key].data) {
          if (!repos[url]) repos[url] = json[key].data[url];
          for (k in json[key].data[url]) {
            if (!repos[url][k]) repos[url][k] = json[key].data[url][k];
          }
        }
      }
      document.trRepos = repos;
    } // updateReposData;

    function updateReposTable () {
      var section = document.querySelector ('.repos');
      var table = section.querySelector ('table');
      var tbody = table.tBodies[0];
      var template = section.querySelector ('.repo-row-template');
      var trueText = template.getAttribute ('data-true');
      var falseText = template.getAttribute ('data-false');
      var naText = template.getAttribute ('data-na');
      tbody.textContent = '';
      var repos = [];
      var filter = section.querySelector ('input[type=search]').value;
      for (var url in document.trRepos) {
        var repo = document.trRepos[url];
        if (url.indexOf (filter) > -1) repos.push (repo);
      }
      repos = repos.sort (function (a, b) {
        return a.scopes && !b.scopes ? -1 :
               !a.scopes && b.scopes ? 1 :
               a.url < b.url ? -1 : +1;
      });
      repos.forEach (function (repo) {
        var tr = document.createElement ('tr');
        tr.innerHTML = template.innerHTML;
        tr.querySelector ('a').href = '/tr/' + encodeURIComponent (repo.url) + '/';
        tr.querySelector ('.label').textContent = repo.label || repo.url;
        var desc = tr.querySelector ('.desc');
        desc.textContent = repo.desc || '';
        desc.hidden = !desc.textContent.length;
        var scopes;
        if (repo.scopes) {
          tr.querySelector ('.join-actions').hidden = true;
          scopes = repo.scopes;
          tr.querySelector ('.scope-read').textContent = scopes.read ? trueText : falseText;
          tr.querySelector ('.scope-edit').textContent = scopes.edit ? trueText : falseText;
          tr.querySelector ('.scope-repo').textContent = scopes.repo ? trueText : falseText;
        } else {
          scopes = repo.remote_scopes || {pull: false, push: false};
          tr.querySelector ('.as-owner').disabled = !scopes.push;
          tr.querySelector ('.scope-read').textContent = naText;
          tr.querySelector ('.scope-edit').textContent = naText;
          tr.querySelector ('.scope-repo').textContent = naText;
        }
        tbody.appendChild (tr);
      }); // repo
    } // updateReposTable

    document.trRepos = {};
    loadRepos ();
  </script>

  <section id=add-repo>
    <h1>リポジトリーを追加</h1>

    <form action=javascript: onsubmit="
      var url = this.elements.url.value;
      location.href = '/tr/' + encodeURIComponent (url) + '/';
      return false;
    ">
      <table class=config>
        <tbody>
          <th><label for=add-repo-url>Git リポジトリー URL</label>
          <td><input name=url id=add-repo-url required>
      </table>
      <p class=buttons><button type=submit>追加</button>
    </form>
  </section>
</section>

<t:include path=_footer.html.tm />
<script src=/js/time.js />
<script> new TER (document.body) </script>
