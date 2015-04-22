<html t:params=$app>
<t:include path=_macro.html.tm />
<title>リポジトリー規則の編集 - TR</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section class=rules>
  <h1>リポジトリー規則</h1>

  <form action=javascript: onchange=document.trModified=true>
    <ul>
      <template>
        <table class=config>
          <tbody>
            <tr>
              <th><label data-for={id}-prefix>URL の先頭</label>
              <td><input name=prefix data-id={id}-prefix required>
            <tr>
              <th><label data-for={id}-canonical_prefix>正規化結果</label>
              <td><input name=canonical_prefix data-id={id}-canonical_prefix>
            <tr>
              <th><label data-for={id}-mapped_prefix>写像先</label>
              <td><input name=mapped_prefix data-id={id}-mapped_prefix>
            <tr>
              <th><label data-for={id}-repository_type>種別</label>
              <td>
                <select name=repository_type required>
                  <option value>(リポジトリーの種別)
                  <option value=github>GitHub
                  <option value=ssh>ssh
                  <option value=file-public>サーバー上のファイル (全公開)
                  <option value=file-private>サーバー上のファイル (限定公開)
                </select>
        </table>
        <button type=button onclick="
          if (confirm (getAttribute ('data-confirm'))) {
            parentNode.parentNode.removeChild (parentNode);
            document.trModified = true;
          }
        " data-confirm=削除します>削除</button>
      </template>
    </ul>
    <p><button type=button class=add>規則を追加</button>

    <p class=buttons><button type=submit>変更を保存</button>

    <div class=status hidden><progress/> <span class=message /></div>
    <script src=/js/core.js charset=utf-8 />
    <script>
      (function () {
        var rulesContainer = document.querySelector ('.rules');
        var list = rulesContainer.querySelector ('ul');
        var status = rulesContainer.querySelector ('.status');
        showProgress ({init: true, message: 'Loading...'}, status);
        server ('GET', 'repository-rules.ndjson', null, function (res) {
          var json = res.data;

          var rules = json.rules instanceof Array ? json.rules : [];
          var template = rulesContainer.querySelector ('template');
          rules.forEach (function (rule) {
            rule = rule || {};
            var li = document.createElement ('li');
            li.innerHTML = template.innerHTML;
            li.querySelector ('[name=prefix]').value = rule.prefix;
            li.querySelector ('[name=canonical_prefix]').value = rule.canonical_prefix || '';
            li.querySelector ('[name=mapped_prefix]').value = rule.mapped_prefix || '';
            li.querySelector ('[name=repository_type]').value = rule.repository_type;
            var id = Math.random ();
            Array.prototype.forEach.call (li.querySelectorAll ('[data-id]'), function (el) {
              el.id = el.getAttribute ('data-id').replace (/\{id\}/g, id);
            });
            Array.prototype.forEach.call (li.querySelectorAll ('[data-for]'), function (el) {
              el.htmlFor = el.getAttribute ('data-for').replace (/\{id\}/g, id);
            });
            list.appendChild (li);
          });

          rulesContainer.querySelector ('.add').onclick = function () {
            var li = document.createElement ('li');
            li.innerHTML = template.innerHTML;
            var id = Math.random ();
            Array.prototype.forEach.call (li.querySelectorAll ('[data-id]'), function (el) {
              el.id = el.getAttribute ('data-id').replace (/\{id\}/g, id);
            });
            Array.prototype.forEach.call (li.querySelectorAll ('[data-for]'), function (el) {
              el.htmlFor = el.getAttribute ('data-for').replace (/\{id\}/g, id);
            });
            list.appendChild (li);
          };

          status.hidden = true;
        }, function (json) {
          showError (json, status);
        }, function (json) {
          showProgress (json, status);
        });

        rulesContainer.querySelector ('form').onsubmit = function () {
          var fd = new FormData;

          var json = {rules: []};
          Array.prototype.forEach.call (list.children, function (li) {
            if (li.localName !== 'li') return;

            var rule = {};
            rule.prefix = li.querySelector ('[name=prefix]').value;
            rule.canonical_prefix = li.querySelector ('[name=canonical_prefix]').value;
            if (rule.canonical_prefix === "") delete rule.canonical_prefix;
            rule.mapped_prefix = li.querySelector ('[name=mapped_prefix]').value;
            if (rule.mapped_prefix === "") delete rule.mapped_prefix;
            rule.repository_type = li.querySelector ('[name=repository_type]').value;
            json.rules.push (rule);
          });
          fd.append ('json', JSON.stringify (json));

          showProgress ({init: true, message: 'Saving...'}, status);
          server ('POST', 'repository-rules.ndjson', fd, function (res) {
            var json = res.data;
            showDone (json, status);
            document.trModified = false;
          }, function (json) {
            showError (json, status);
          }, function (json) {
            showProgress (json, status);
          });
          return false;
        };
      }) ();
    </script>
  </form>

</section>

<t:include path=_footer.html.tm m:app=$app />
