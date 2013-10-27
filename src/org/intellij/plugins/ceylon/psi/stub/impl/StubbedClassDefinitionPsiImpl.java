package org.intellij.plugins.ceylon.psi.stub.impl;

import com.intellij.lang.ASTNode;
import org.intellij.plugins.ceylon.psi.impl.CeylonClassImpl;
import org.intellij.plugins.ceylon.psi.stub.StubbedClassDefinitionPsi;

public class StubbedClassDefinitionPsiImpl extends CeylonClassImpl implements StubbedClassDefinitionPsi {
    public StubbedClassDefinitionPsiImpl(ASTNode node) {
        super(node);
    }
}
