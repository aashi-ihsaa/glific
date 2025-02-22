defmodule Glific.GroupsTest do
  use Glific.DataCase

  alias Glific.{
    Contacts,
    Groups,
    Groups.Group,
    Groups.UserGroup,
    Seeds.SeedsDev,
    Users
  }

  describe "groups" do
    @valid_attrs %{
      label: "some group",
      is_restricted: false
    }
    @valid_other_attrs %{
      label: "some other group",
      is_restricted: true
    }
    @update_attrs %{
      label: "updated group",
      is_restricted: false
    }
    @invalid_attrs %{
      label: nil
    }

    def group_fixture(attrs) do
      {:ok, group} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Groups.create_group()

      group
    end

    test "list_groups/1 returns all groups", attrs do
      group = group_fixture(attrs)
      assert Groups.list_groups(%{filter: Map.put(attrs, :label, group.label)}) == [group]
    end

    test "count_groups/1 returns count of all groups", attrs do
      _ = group_fixture(attrs)
      assert Groups.count_groups(%{filter: attrs}) == 4

      _ = group_fixture(Map.merge(attrs, @valid_other_attrs))
      assert Groups.count_groups(%{filter: attrs}) == 5

      assert Groups.count_groups(%{filter: Map.merge(attrs, %{label: "other group"})}) == 1
    end

    test "get_group!/1 returns the group with given id", attrs do
      group = group_fixture(attrs)
      assert Groups.get_group!(group.id) == group
    end

    test "get_or_create_group_by_label!/1 creates and returns a group if label does not exist",
         attrs do
      label = "Group"
      current_count = Groups.count_groups(%{filter: %{label: label}})

      assert current_count == 0

      {:ok, group} = Groups.get_or_create_group_by_label(label, attrs.organization_id)
      count = Groups.count_groups(%{filter: %{label: label}})

      assert count == 1
      assert group.label == label
    end

    test "get_or_create_group_by_label!/1 retrieves a group if label exists", attrs do
      label = "Group"
      existing_group = group_fixture(Map.merge(%{label: label}, attrs))

      {:ok, group} =
        Groups.get_or_create_group_by_label(existing_group.label, attrs.organization_id)

      assert group == existing_group
    end

    test "create_group/1 with valid data creates a group", attrs do
      assert {:ok, %Group{} = group} = Groups.create_group(Map.merge(attrs, @valid_attrs))
      assert group.is_restricted == false
      assert group.label == "some group"
    end

    test "create_group/1 with invalid data returns error changeset", attrs do
      assert {:error, %Ecto.Changeset{}} = Groups.create_group(Map.merge(attrs, @invalid_attrs))
    end

    test "update_group/2 with valid data updates the group", attrs do
      group = group_fixture(attrs)
      assert {:ok, %Group{} = group} = Groups.update_group(group, @update_attrs)
      assert group.label == "updated group"
      assert group.is_restricted == false
    end

    test "update_group/2 with invalid data returns error changeset", attrs do
      group = group_fixture(attrs)

      assert {:error, %Ecto.Changeset{}} =
               Groups.update_group(group, Map.merge(attrs, @invalid_attrs))

      assert group == Groups.get_group!(group.id)
    end

    test "delete_group/1 deletes the group", attrs do
      group = group_fixture(attrs)
      assert {:ok, %Group{}} = Groups.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Groups.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset", attrs do
      group = group_fixture(attrs)
      assert %Ecto.Changeset{} = Groups.change_group(group)
    end

    test "list_groups/1 with multiple items", attrs do
      group1 = group_fixture(attrs)
      group2 = group_fixture(Map.merge(attrs, @valid_other_attrs))
      groups = Groups.list_groups(%{filter: Map.put(attrs, :label, "some")})
      assert length(groups) == 2
      [h, t | _] = groups
      assert (h == group1 && t == group2) || (h == group2 && t == group1)
    end

    test "load_group_by_label", attrs do
      group_fixture(attrs)

      group_fixture(Map.merge(attrs, @valid_other_attrs))

      result = Groups.load_group_by_label(["some group", "some other group"])

      assert Enum.empty?(result) == false
    end

    test "list_groups/1 with multiple items sorted", attrs do
      group1 = group_fixture(attrs)
      group2 = group_fixture(Map.merge(attrs, @valid_other_attrs))
      groups = Groups.list_groups(%{opts: %{order: :asc}, filter: Map.put(attrs, :label, "some")})
      assert length(groups) == 2
      [h, t | _] = groups
      assert h == group1 && t == group2
    end

    test "list_groups/1 with items filtered", attrs do
      _group1 = group_fixture(attrs)
      group2 = group_fixture(Map.merge(attrs, @valid_other_attrs))

      groups =
        Groups.list_groups(%{
          opts: %{order: :asc},
          filter: Map.merge(attrs, %{label: "some other group"})
        })

      assert length(groups) == 1
      [h] = groups
      assert h == group2
    end
  end

  describe "contacts_groups" do
    setup do
      default_provider = SeedsDev.seed_providers()
      SeedsDev.seed_organizations(default_provider)
      SeedsDev.seed_contacts()
      :ok
    end

    test "create_contacts_group/1 with valid data creates a group", attrs do
      [contact | _] = Contacts.list_contacts(%{filter: attrs})
      group = group_fixture(attrs)

      {:ok, contact_group} =
        Groups.create_contact_group(%{
          contact_id: contact.id,
          group_id: group.id,
          organization_id: attrs.organization_id
        })

      assert contact_group.contact_id == contact.id
      assert contact_group.group_id == group.id
    end

    test "ensure that creating contact_group with same contact and group returns the existing one",
         attrs do
      [contact | _] = Contacts.list_contacts(%{filter: attrs})
      group = group_fixture(attrs)

      {:ok, cg1} =
        Groups.create_contact_group(%{
          contact_id: contact.id,
          group_id: group.id,
          organization_id: attrs.organization_id
        })

      # here we just want to ensure an error happened
      # since we are forgiving in this api call and allow a contact to be added to the
      # same group
      {:ok, cg2} =
        Groups.create_contact_group(%{
          contact_id: contact.id,
          group_id: group.id,
          organization_id: attrs.organization_id
        })

      assert cg1 == cg2
    end
  end

  describe "users_groups" do
    setup do
      SeedsDev.seed_users()
      :ok
    end

    def user_group_fixture(attrs) do
      [user | _] = Users.list_users(%{filter: attrs})

      valid_attrs = %{
        user_id: user.id,
        group_id: group_fixture(attrs).id
      }

      {:ok, user_group} =
        valid_attrs
        |> Groups.create_user_group()

      user_group
    end

    test "create_users_group/1 with valid data creates a group", attrs do
      [user | _] = Users.list_users(%{filter: attrs})
      group = group_fixture(attrs)

      {:ok, user_group} =
        Groups.create_user_group(%{
          user_id: user.id,
          group_id: group.id,
          organization_id: user.organization_id
        })

      assert user_group.user_id == user.id
      assert user_group.group_id == group.id
    end

    test "ensure that creating user_group with same user and group give an error", attrs do
      [user | _] = Users.list_users(%{filter: attrs})
      group = group_fixture(attrs)
      Groups.create_user_group(%{user_id: user.id, group_id: group.id})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_user_group(%{user_id: user.id, group_id: group.id})
    end

    test "update_user_groups/1 should add and delete user groups according to the input", attrs do
      [user | _] = Users.list_users(%{filter: attrs})
      group_1 = group_fixture(attrs)
      group_2 = group_fixture(Map.merge(attrs, %{label: "new group"}))
      group_3 = group_fixture(Map.merge(attrs, %{label: "another group"}))

      # add user groups
      :ok =
        Groups.update_user_groups(%{
          user_id: user.id,
          group_ids: ["#{group_1.id}", "#{group_2.id}"],
          organization_id: user.organization_id
        })

      user_group_ids =
        UserGroup
        |> where([ug], ug.user_id == ^user.id)
        |> select([ug], ug.group_id)
        |> Repo.all()

      assert user_group_ids == [group_1.id, group_2.id]

      # update user groups
      :ok =
        Groups.update_user_groups(%{
          user_id: user.id,
          group_ids: ["#{group_1.id}", "#{group_3.id}"],
          organization_id: user.organization_id
        })

      user_group_ids =
        UserGroup
        |> where([ug], ug.user_id == ^user.id)
        |> select([ug], ug.group_id)
        |> Repo.all()

      assert user_group_ids == [group_1.id, group_3.id]
    end
  end
end
