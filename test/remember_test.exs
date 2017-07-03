defmodule Phauxth.RememberTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  alias Phauxth.{Authenticate, Remember, SessionHelper, TestAccounts}

  @max_age 7 * 24 * 60 * 60

  defmodule Endpoint do
    def config(:secret_key_base), do: "abc123"
  end

  setup do
    conn = conn(:get, "/")
           |> put_private(:phoenix_endpoint, Endpoint)
           |> SessionHelper.sign_conn
           |> Remember.add_rem_cookie(1)

    {:ok, %{conn: conn}}
  end

  test "init function" do
    assert Remember.init([]) ==
      {nil, 2419200, Phauxth.Accounts}
    assert Remember.init([max_age: 100]) ==
      {nil, 100, Phauxth.Accounts}
  end

  test "call remember with default options", %{conn: conn} do
    conn = SessionHelper.recycle_and_sign(conn)
           |> put_private(:phoenix_endpoint, Endpoint)
           |> Remember.call({nil, @max_age, TestAccounts})
    %{current_user: user} = conn.assigns
    assert user.username == "fred"
    assert user.role == "user"
  end

  test "error log when the cookie is invalid", %{conn: conn} do
    invalid = "SFMyNTY.g3QAAAACZAAEZGF0YWeBZAAGc2lnbmVkbgYAHU1We1sB.mMbd1DOs-1UnE29sTg1O9QC_l1YAHURVe7FsTTsXj88"
    conn = put_resp_cookie(conn, "remember_me", invalid, [http_only: true, max_age: 604_800])
    assert capture_log(fn ->
      conn(:get, "/")
      |> recycle_cookies(conn)
      |> SessionHelper.sign_conn
      |> Remember.call({Endpoint, @max_age, TestAccounts})
    end) =~ ~s(user=nil message="invalid token")
  end

  test "call remember with no remember cookie" do
    conn = conn(:get, "/")
           |> SessionHelper.sign_conn
           |> Remember.call({Endpoint, @max_age, TestAccounts})
    refute conn.assigns[:current_user]
  end

  test "call remember with current_user already set", %{conn: conn} do
    conn = SessionHelper.recycle_and_sign(conn)
           |> put_session(:user_id, 4)
           |> Authenticate.call({nil, @max_age, TestAccounts})
           |> Remember.call({Endpoint, @max_age, TestAccounts})
    %{current_user: user} = conn.assigns
    assert user.id == 4
    assert user.email == "brian@mail.com"
  end

  test "add cookie", %{conn: conn} do
    conn = SessionHelper.recycle_and_sign(conn)
    assert conn.req_cookies["remember_me"]
  end

  test "delete cookie", %{conn: conn} do
    conn = Remember.delete_rem_cookie(conn)
           |> send_resp(200, "")
    refute conn.req_cookies["remember_me"]
  end

  test "output to current_user does not contain password_hash" , %{conn: conn} do
    conn = SessionHelper.recycle_and_sign(conn)
           |> Remember.call({Endpoint, @max_age, TestAccounts})
    %{current_user: user} = conn.assigns
    refute Map.has_key?(user, :password_hash)
  end

end
