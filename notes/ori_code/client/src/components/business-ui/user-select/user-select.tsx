'use client';

import { useCallback, useMemo } from 'react';

import { searchUsers, type AccountType } from '@client/src/components/business-ui/api/users/service';
import { BaseCombobox } from '@client/src/components/business-ui/entity-combobox/base-combobox';
import { useEntityComboboxContext } from '@client/src/components/business-ui/entity-combobox/context';
import type {
  UserSelectItemValue,
  UserSelectProps,
} from '@client/src/components/business-ui/user-select/types';
import { useUserValue } from '@client/src/components/business-ui/user-select/use-user-value';
import { UserItem } from '@client/src/components/business-ui/user-select/user-item';
import { UserSelectTag } from '@client/src/components/business-ui/user-select/user-select-tag';
import { searchUserInfoToUser } from '@client/src/components/business-ui/user-select/utils';

function createUsersFetcher(options: { accountType?: AccountType; pageSize?: number } = {}) {
  const { accountType = 'apaas', pageSize = 100 } = options;

  return async (search: string) => {
    const response = await searchUsers({ query: search, pageSize });
    const userList = response?.data?.userList || [];

    return {
      items: userList.map((user) => searchUserInfoToUser(user, accountType)),
    };
  };
}

// 内部包装组件用于获取 context 中的 size
const UserItemWrapper = ({
  userValue,
  isSelected,
  className,
  disabled,
}: {
  userValue: UserSelectItemValue;
  isSelected: boolean;
  className?: string;
  disabled?: boolean;
}) => {
  const { size, searchValue } = useEntityComboboxContext();
  return (
    <UserItem
      userValue={userValue}
      isSelected={isSelected}
      className={className}
      size={size}
      searchKeyword={searchValue}
      disabled={disabled}
    />
  );
};

const UserSelectTagWrapper = ({
  userValue,
  onClose,
  className,
  disabled,
  isLoading,
  accountType,
}: {
  userValue: UserSelectItemValue;
  onClose: (value: UserSelectItemValue, e: React.MouseEvent) => void;
  className?: string;
  disabled?: boolean;
  isLoading?: boolean;
  accountType?: 'apaas' | 'lark';
}) => {
  const { size } = useEntityComboboxContext();
  return (
    <UserSelectTag
      userValue={userValue}
      onClose={onClose}
      className={className}
      size={size}
      disabled={disabled}
      isLoading={isLoading}
      accountType={accountType}
    />
  );
};

export const UserSelect: React.FC<UserSelectProps> = (props) => {
  const {
    size = 'medium',
    triggerType = 'button',
    renderTrigger,
    multiple = false,
    value,
    valueType = 'string',
    accountType = 'apaas',
    defaultValue,
    onChange,
    defaultOpen,
    disabled,
    autoFocus,
    required,
    name,
    className,
    classNames,
    placeholder = '请选择',
    emptyText = '没有匹配结果，换个关键词试试吧',
    tagClosable,
    maxTagCount,
    onSelect,
    onDeselect,
    onClear,
    onFocus,
    onBlur,
    slotProps,
    getOptionDisabled,
  } = props;

  // 使用 useUserValue 处理不同类型的 value（包括 defaultValue）
  const { internalValue, isLoading, toExternalValue } = useUserValue(
    value ?? null,
    multiple,
    accountType,
    valueType,
  );

  // 同样处理 defaultValue，确保 ID 字符串类型的 defaultValue 也能正确解析
  const { internalValue: internalDefaultValue } = useUserValue(
    defaultValue ?? null,
    multiple,
    accountType,
    valueType,
  );

  const fetchFn = useMemo(() => createUsersFetcher({ accountType }), [accountType]);

  // 包装 onChange，根据输入模式转换输出格式
  const handleChange = useCallback(
    (newValue: UserSelectItemValue | UserSelectItemValue[] | null) => {
      if (!onChange) return;

      const externalValue = toExternalValue(newValue, multiple);
      (onChange as (value: unknown) => void)(externalValue);
    },
    [onChange, toExternalValue, multiple],
  );

  const renderTagWithLoading = useCallback(
    (
      userValue: UserSelectItemValue,
      onClose: (value: UserSelectItemValue, e: React.MouseEvent) => void,
      tagDisabled?: boolean,
    ) => (
      <UserSelectTagWrapper
        key={userValue.id}
        userValue={userValue}
        onClose={onClose}
        disabled={tagDisabled}
        isLoading={isLoading}
        accountType={accountType}
      />
    ),
    [isLoading, accountType],
  );

  return (
    <BaseCombobox
      autoFocus={autoFocus}
      className={className}
      classNames={classNames}
      debounce={300}
      defaultOpen={defaultOpen}
      defaultValue={internalDefaultValue}
      disabled={disabled}
      emptyText={emptyText}
      fetchFn={fetchFn}
      getItemLabel={(userValue) => userValue.name}
      getItemValue={(userValue) => userValue}
      getOptionDisabled={getOptionDisabled}
      maxTagCount={maxTagCount}
      multiple={multiple}
      name={name}
      onBlur={onBlur}
      onChange={handleChange}
      onClear={onClear}
      onDeselect={onDeselect}
      onFocus={onFocus}
      onSelect={onSelect}
      placeholder={placeholder}
      renderItem={(userValue, isSelected, itemClassName, itemDisabled) => (
        <UserItemWrapper
          key={userValue.id}
          userValue={userValue}
          isSelected={isSelected}
          className={itemClassName}
          disabled={itemDisabled}
        />
      )}
      renderTag={renderTagWithLoading}
      renderTrigger={renderTrigger}
      required={required}
      searchPlaceholder=""
      showSearch
      size={size}
      slotProps={slotProps}
      tagClosable={tagClosable}
      triggerType={triggerType}
      value={internalValue}
    />
  );
};

export { type UserSelectItemValue as UserValue };

export { ItemPill } from '@client/src/components/business-ui/entity-combobox/item-pill';
