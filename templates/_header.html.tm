<header class=site>
<h1><a href="/" rel=index>TR</a></h1>

<nav>
  <div class=account>
    <button type=button class=account-menu-button onclick="
      var menu = parentNode.querySelector ('menu');
      menu.hidden = !menu.hidden;
    ">アカウント</button>
    <menu hidden class=contextmenu>
      <p><a href=/tr>リポジトリー一覧</a>
      <div class=login-menu>
        <div class=header>
          <strong>ログイン</strong>
          <button type=button class=close onclick="
            parentNode.parentNode.parentNode.hidden = true;
          " title=閉じる>閉じる</button>
        </div>
        <form action=/account/login method=post class=login>
          <button type=submit name=server value=github>GitHub アカウントでログイン</button>
          <button type=submit name=server value=hatena>はてなIDでログイン</button>
        </form>
      </div>
    </menu>
    <script>
      var input = document.createElement ('input');
      input.type = 'hidden';
      input.name = 'next';
      input.value = location.href;
      document.forms[document.forms.length-1].appendChild (input);

      var xhr = new XMLHttpRequest;
      xhr.open ('GET', '/account/info.json', true);
      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            var json = JSON.parse (xhr.responseText);
            if (json.name) {
              var account = document.querySelector ('header.site .account');
              var button = account.querySelector ('.account-menu-button');
              button.textContent = json.name;
              account.classList.add ('has-account');
              if (json.account_id) {
                document.documentElement.setAttribute ('data-account-id', json.account_id);
              }
            }
          }
        }
      };
      xhr.send (null);

      function login () {
        if (document.trLoginDialog) {
          document.trLoginDialog.hidden = false;
          document.trLoginDialog.style.top = document.body.scrollTop + 'px';
          return;
        }

        var div = document.trLoginDialog = document.createElement ('div');
        div.className = 'dialog';
        div.appendChild (document.querySelector ('header.site .login-menu').cloneNode (true));
        div.style.top = document.body.scrollTop + 'px';
        document.body.appendChild (div);
      } // login
    </script>
  </div>

  <a href="/help">Documentation</a>
</nav>
</header>
