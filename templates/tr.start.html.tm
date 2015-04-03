<html t:params="$tr $app" class=config-page>
<title>初期設定 - Repository configuration - XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="./" rel="up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    </hgroup>
  </header>

  <nav>
    <p class=done>ログイン
    <p class=done><a href=/tr>リポジトリー選択</a>
    <p class=selected><a href>編集対象選択</a>
    <p>インポート
    <p>言語設定
    <p>ライセンス設定
    <p>初期設定完了
  </nav>

  <section class="config choose-text-set">
    <header>
      <h1>初期設定</h1>
    </header>
    <p class=status hidden><progress></progress> <span class=message></span>

    <form action=javascript: onsubmit="
      var branch = elements.branch.value;
      var path = elements.path.value;
      if (!branch || !path) return;
      location.href = encodeURIComponent (branch) + '/' + encodeURIComponent (path) + '/start';
      return false;
    ">
      <table class="config">
        <tbody>
          <tr>
            <th><label for=choose-text-set-branch>ブランチ</label>
            <td>
              <select id=choose-text-set-branch name=branch required onchange=" loadTextSets () ">
                <option value>ブランチを選択
              </select>
              <button type=button onclick=" loadBranches () ">再読込</button>
              <p class=help>
                編集するブランチを選択してください。
                新しいブランチを使うには、
                <a href=XXX>GitHub でブランチを作成</a>してください。
          <tr>
            <th><label for=choose-text-set-path>テキスト集合</label>
            <td>
              <input id=choose-text-set-path name=path pattern="(?:/[0-9a-zA-Z_.-]+)+" required title="/path/to/text-set" placeholder="/myapp/data" value=/ list=choose-text-set-path-list>
              <datalist id=choose-text-set-path-list class=path-list />
              <p class=help>
                テキスト集合を保存するディレクトリーを指定してください。
      </table>

      <p class=buttons><button type=submit>次へ進む</button>
    </form>

      <script src=/js/core.js charset=utf-8 />
      <script>
        function loadBranches () {
          var status = document.querySelector ('.status');
          showProgress ({init: true, message: 'Loading...'}, status);
          server ('GET', 'info.ndjson', null, function (res) {
            var opts = document.querySelector ('.choose-text-set select[name=branch]');
            while (opts.childNodes.length > 1) {
              opts.removeChild (opts.lastChild);
            }
            for (var n in res.data.branches) {
              var branch = res.data.branches[n];
              var opt = document.createElement ('option');
              opt.label = branch.name;
              opt.value = branch.name;
              if (branch.selected) opt.selected = true;
              opts.appendChild (opt);
            }
            loadTextSets ();
            status.hidden = true;
          }, function (json) {
            showError (json, status);
          }, function (json) {
            showProgress (json, status);
          });
        } // loadBranches

        function loadTextSets () {
          var status = document.querySelector ('.status');
          var branchName = document.querySelector ('.choose-text-set select[name=branch]').value;
          if (!branchName) return;
          showProgress ({init: true, message: 'Loading...'}, status);
          server ('GET', encodeURIComponent (branchName) + '/info.ndjson', null, function (res) {
            var opts = document.querySelector ('.choose-text-set datalist.path-list');
            opts.textContent = '';
            for (var n in res.data.text_sets) {
              var textSet = res.data.text_sets[n];
              var opt = document.createElement ('option');
              opt.label = textSet.path;
              opt.value = textSet.path;
              opts.appendChild (opt);
            }
            status.hidden = true;
          }, function (json) {
            showError (json, status);
          }, function (json) {
            showProgress (json, status);
          });
        } // loadTextSets

        loadBranches ();
      </script>

  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
