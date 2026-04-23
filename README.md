# Azure Retiring Feature Impact Assessment Tool

## Prerequisites

1. **Azure CLI**
   - Install: https://learn.microsoft.com/cli/azure/install-azure-cli
   - Login before running the script:
     ```
     az login --environment AzureChinaCloud
     ```

2. **PowerShell** — Works with PowerShell 5.1+ (built-in on Windows)

## File Structure

Place the following files in the **same folder**:

```
YourFolder\
├── run-arg-queries.ps1   (Script)
└── queries.txt           (Query file, provided)
```

## Usage

```powershell
# All subscriptions
.\run-arg-queries.ps1

# Specific subscription
.\run-arg-queries.ps1 -Subscriptions "<your-subscription-id>"

# Multiple subscriptions
.\run-arg-queries.ps1 -Subscriptions "<sub-id-1>","<sub-id-2>"
```

## Output

- Console will display impacted resources for each retiring feature.
- If impacted resources are found, a CSV file `impactedresources.csv` will be generated in the same folder.
- If no resources are impacted, NO CSV file will be generated — this means your environment is not affected.

## Troubleshooting

**1. Execution Policy Error**

If you see "cannot be loaded because the file is not digitally signed":

```powershell
Unblock-File .\run-arg-queries.ps1
```

Or bypass for a single run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-arg-queries.ps1
```

**2. Azure CLI Not Logged In**

If you see authentication errors, please login first:

```
az login --environment AzureChinaCloud
```

**3. No Output File Generated**

This is expected when no resources are impacted. Check the console output — it should show "No resources impacted".

---

# Azure 退役功能影响评估工具

## 前置条件

1. **Azure CLI**
   - 安装：https://learn.microsoft.com/cli/azure/install-azure-cli
   - 运行脚本前请先登录：
     ```
     az login --environment AzureChinaCloud
     ```

2. **PowerShell** — 适用于 PowerShell 5.1+（Windows 自带）

## 文件结构

请将以下文件放在**同一个文件夹**中：

```
YourFolder\
├── run-arg-queries.ps1   (脚本)
└── queries.txt           (查询文件，已提供)
```

## 使用方法

```powershell
# 查询所有订阅
.\run-arg-queries.ps1

# 指定订阅
.\run-arg-queries.ps1 -Subscriptions "<your-subscription-id>"

# 多个订阅
.\run-arg-queries.ps1 -Subscriptions "<sub-id-1>","<sub-id-2>"
```

## 输出说明

- 控制台会显示每个退役功能的受影响资源。
- 如果有受影响的资源，会在同一文件夹下生成 `impactedresources.csv` 文件。
- 如果没有受影响的资源，不会生成 CSV 文件——这说明您的环境未受影响。

## 常见问题

**1. 执行策略报错**

如果提示"文件未经数字签名，无法加载"：

```powershell
Unblock-File .\run-arg-queries.ps1
```

或单次绕过执行策略：

```powershell
powershell -ExecutionPolicy Bypass -File .\run-arg-queries.ps1
```

**2. 未登录 Azure CLI**

如果出现认证错误，请先登录：

```
az login --environment AzureChinaCloud
```

**3. 没有生成输出文件**

这是正常现象，说明没有受影响的资源。请查看控制台输出，应显示 "No resources impacted"。
