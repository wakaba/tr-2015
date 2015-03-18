<html t:params="$tr $tr_config $app">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="../../" rel="up up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
      <h2 title=Branch><a href="../" rel="up up"><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
      <h3 title=Path><a href="./" rel=up><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
    </hgroup>
  </header>

  <section>
    <header>
      <h1>編集権限設定</h1>
    </header>

    <table class=acl>
      <thead>
        <tr>
          <th>アカウント
          <th>権限
          <th>
      </thead>
      <template class=acl-row-template>
        <th><span class=account>{account}</span>
        <td>
          <form action=acl method=post>
            <input type=hidden name=operation value=update_account_privilege>
            <ul>
              <li><label><input type=checkbox checked disabled> テキストの表示</label>
              <li><label><input type=checkbox name=scope value=edit> テキストの編集</label>
                <ul>
                  <li><label><input type=checkbox name=scope value=edit/en> 英語</label>
                  <li><label><input type=checkbox name=scope value=edit/ja> 日本語</label>
                </ul>
              <li><label><input type=checkbox name=scope value=comment> コメントの投稿</label>
              <li><label><input type=checkbox name=scope value=texts> テキストの管理</label>
              <li><label><input type=checkbox name=scope value=repo> リポジトリーの管理</label>
            </ul>
          </form>
        <td>
          <p><button type=button class=save-button>変更を保存</button>
          <p><button type=button class=delete-button>削除</button>
      </template>
      <tbody>
    </table>

    <div class=add-account>
      <input>
      <template class=datalist-item-template>
        <template>
          <span class=name>{name}</span> <span class=key>{key}</span>
          <span class=service>{service}</span>
        </template>
        <button type=button onclick=" addAclItemByDatalistItem (this.parentNode).scrollIntoView () ">追加</button>
      </template>
      <ul class=datalist></ul>
    </div>

      <table class=config>
        <tbody>
          <tr>
            <th>所有者
            <td><span class=owner-account data-no-owner="未設定"></span>
              <form action=acl method=post>
                <input type=hidden name=operation value=get_ownership>
                <button type=submit>所有権を取得</button>
              </form><!-- XXX ajax -->
              <p class=info>Git リポジトリーへの変更は所有者の権限で保存
                (<code>git push</code>) されます。
      </table>
    <p class=status hidden><progress></progress> <span class=message></span>

    <script>
      function addDatalistItem (account) {
        var addDatalist = document.querySelector ('.add-account .datalist');
        var addDatalistTemplate = document.querySelector ('.add-account .datalist-item-template');
        var option = document.createElement ('li');
        option.innerHTML = addDatalistTemplate.innerHTML;
        option.setAttribute ('data-account-id', account.account_id);
        var serviceTemplate = option.querySelector ('template');
        var services = [];
        for (var serviceName in account.services) {
          var serviceAccount = account.services[serviceName];
          var service = document.createElement ('p');
          service.className = 'service-account';
          service.innerHTML = serviceTemplate.innerHTML;
          service.querySelector ('.service').textContent = serviceName;
          service.querySelector ('.name').textContent = serviceAccount.name;
          service.querySelector ('.key').textContent = serviceAccount.key || serviceAccount.id;
          option.insertBefore (service, serviceTemplate);
        }
        addDatalist.appendChild (option);
      } // addDatalistItem

      function addAclItem (account) {
        var row = document.createElement ('tr');
        row.innerHTML = document.querySelector ('table.acl .acl-row-template').innerHTML;
        row.setAttribute ('data-account-id', account.account_id);

        var accountEl = row.querySelector ('.account');
        accountEl.textContent = account.name;
        // XXX link, icon

        var form = row.querySelector ('form');
        Array.prototype.forEach.call (form.querySelectorAll ('input[name=scope]'), function (input) {
          input.checked = !!account.scopes[input.value];
          input.onchange = function () {
            row.classList.add ('modified');
          };
        });

        row.querySelector ('.save-button').onclick = function () {
          // XXX progress
          var xhr = new XMLHttpRequest;
          xhr.open ('POST', form.action, true);
          var fd = new FormData (form);
          fd.append ('account_id', row.getAttribute ('data-account-id'));
          xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
              if (xhr.status === 200 || xhr.status === 204) {
                row.classList.remove ('modified');
              } else {
                // XXX
              }
            }
          };
          xhr.send (fd);
          return false;
        };
        row.querySelector ('.delete-button').onclick = function () {
          // XXX progress
          var xhr = new XMLHttpRequest;
          xhr.open ('POST', form.action, true);
          var fd = new FormData;
          fd.append ('operation', 'delete_account_privilege');
          fd.append ('account_id', row.getAttribute ('data-account-id'));
          xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
              if (xhr.status === 200 || xhr.status === 204) {
                row.parentNode.removeChild (row);
              } else {
                // XXX
              }
            }
          };
          xhr.send (fd);
          return false;
        };

        document.querySelector ('table.acl tbody').appendChild (row);
        return row;
      } // addAclItem

      function addAclItemByDatalistItem (item) {
        var accountId = item.getAttribute ('data-account-id') || '';
        if (!/^[0-9]+$/.test (accountId)) return;
        var row = document.querySelector ('table.acl tr[data-account-id="'+accountId+'"]');
        if (row) return row;
        return addAclItem ({account_id: accountId,
                            name: item.querySelector ('.name').textContent,
                            scopes: {}});
      } // addAclItemByDatalistItem

      (function () {
        // XXX progress
        var xhr = new XMLHttpRequest;
        xhr.open ('GET', 'acl.json', true);
        xhr.onreadystatechange = function () {
          if (xhr.readyState === 4) {
            if (xhr.status === 200) {
              var json = JSON.parse (xhr.responseText);
              var ownerAccount = null;
              for (var accountId in json.accounts) {
                var account = json.accounts[accountId];
                addAclItem (account);
                if (account.is_owner) ownerAccount = account;
              }
              
              var ownerEl = document.querySelector ('.owner-account');
              if (ownerAccount) {
                ownerEl.textContent = ownerAccount.name;
                // XXX icon, link
              } else {
                ownerEl.textContent = ownerEl.getAttribute ('data-no-owner');
              }
            } else {
              // XXX
            }
          }
        };
        xhr.send (null);

        var addInput = document.querySelector ('.add-account input');
        var updateAdd = function () {
          if (!addInput.value) return;
          var xhr = new XMLHttpRequest;
          xhr.open ('POST', '/users/search.json?q=' + encodeURIComponent (addInput.value), true);
          xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
              if (xhr.status === 200) {
                //XXX ignore if next request is dispatched
                var json = JSON.parse (xhr.responseText);
                for (var accountId in json.accounts) {
                  var account = json.accounts[accountId];
                  addDatalistItem (account);
                }
              }
            }
          };
          xhr.send (null);
        };
        var addTimer;
        addInput.oninput = function () {
          clearTimeout (addTimer);
          addTimer = setTimeout (updateAdd, 500);
        };
      }) ();
    </script>
  </section>
</section>

<t:include path=_footer.html.tm />
