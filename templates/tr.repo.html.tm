<html t:params="$tr $app">
<t:include path=_macro.html.tm />
<title>Branches - XXX - TR</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="./" rel=bookmark><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    </hgroup>
  </header>

  <section class=branches>
    <h1>Branches</h1>
    <p class=status hidden><progress/> <span class=message>{status}</span>

    <table>
      <thead>
        <tr>
          <th>Branch
          <th>Last updated
          <th>Commit
      </thead>
      <template class=branch-row-template>
        <!-- onclick="" class=default? -->
        <th><a href><code class=name>{name}</code></a>
        <td><time class=modified>2000-01-01 00:00:00</time>
        <td><span class=commit-message>{commit_message}</span>
      </template>
      <tbody>
    </table>

    <details>
      <summary>ブランチを追加</summary>
      <p class=info>ブランチは <a href=XXX>GitHub で追加</a>できます。
    </details>

    <script src=/js/time.js />
    <script src=/js/core.js charset=utf-8 />
    <script>
      (function () {
        var status = document.querySelector ('.branches .status');
        showProgress ({init: true, message: 'Loading...'}, status);
        server ('GET', 'info.ndjson', null, function (res) {
          var branches = res.data.branches;
          var tbody = document.querySelector ('.branches table tbody');
          var template = document.querySelector ('.branches .branch-row-template');
          for (var n in branches) {
            var branch = branches[n];
            var tr = document.createElement ('tr');
            tr.innerHTML = template.innerHTML;
            if (branch.selected) tr.className = 'selected';
            tr.setAttribute ('data-branch', branch.name);
            tr.onclick = function () { this.querySelector ('a').click () };
            tr.querySelector ('a').href = './' + encodeURIComponent (branch.name) + '/';
            tr.querySelector ('.name').textContent = branch.name;
            tr.querySelector ('.commit-message').textContent = branch.commit_message;
            tr.querySelector ('.modified').textContent = new Date (parseInt (branch.commit_author.time) * 1000).toISOString ();
            tbody.appendChild (tr);
          }
          new TER (tbody);
          status.hidden = true;
        }, function (json) {
          showError (json, status);
        }, function (json) {
          showProgress (json, status);
        });
      }) ();
    </script>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
