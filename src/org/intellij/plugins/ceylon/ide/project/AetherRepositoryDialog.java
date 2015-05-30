package org.intellij.plugins.ceylon.ide.project;

import com.intellij.openapi.ui.DialogWrapper;
import com.intellij.openapi.ui.ValidationInfo;
import com.intellij.openapi.util.text.StringUtil;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.awt.*;
import java.io.File;

public class AetherRepositoryDialog extends DialogWrapper {

    private AetherRepositoryForm form = new AetherRepositoryForm();

    protected AetherRepositoryDialog(Component parent) {
        super(parent, false);
        init();
        setTitle("Add Maven Repository");

    }

    @Nullable
    @Override
    protected JComponent createCenterPanel() {
        return form.getMainPanel();
    }

    @Nullable
    @Override
    public JComponent getPreferredFocusedComponent() {
        return form.getRepoField();
    }

    public String getRepository() {
        return form.getRepoField().getText();
    }

    @Nullable
    @Override
    protected ValidationInfo doValidate() {
        if (StringUtil.isNotEmpty(getRepository())) {
            if (!new File(getRepository()).exists()) {
                return new ValidationInfo("Invalid path to settings.xml", form.getRepoField());
            }
        }
        return null;
    }
}
