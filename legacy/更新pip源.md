要修改pip以默认使用阿里云的索引，你需要设置pip的配置文件。以下是步骤：

1. **创建或修改pip配置文件**：
   - 对于Linux或macOS系统，配置文件通常位于`~/.pip/pip.conf`（`~`代表用户的主目录）。
   - 对于Windows系统，配置文件通常位于`%APPDATA%\pip\pip.ini`。

2. **编辑配置文件**：
   - 如果文件不存在，你需要创建它。
   - 使用文本编辑器打开配置文件。

3. **添加或修改配置**：
   - 在配置文件中添加以下内容，以设置默认的索引源为阿里云的Python包索引：

     ```
     [global]
     index-url = https://mirrors.aliyun.com/pypi/simple
     ```

   - 如果你还想设置额外的索引源作为备用，可以添加`extra-index-url`：

     ```
     [global]
     index-url = https://mirrors.aliyun.com/pypi/simple
     extra-index-url = https://pypi.org/simple
     ```

4. **保存并关闭配置文件**。

5. **验证配置**：
   - 运行`pip config list`命令来查看当前的配置。

6. **使用pip**：
   - 现在当你使用pip安装包时，它将默认使用阿里云的索引源。

请注意，修改配置文件可能需要管理员权限，具体取决于你的操作系统和文件权限设置。如果你在使用虚拟环境，你也可以在虚拟环境的`pip.conf`文件中设置索引源，这样设置只会影响当前的虚拟环境。
