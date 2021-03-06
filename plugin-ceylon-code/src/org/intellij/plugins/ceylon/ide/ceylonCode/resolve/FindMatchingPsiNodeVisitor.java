package org.intellij.plugins.ceylon.ide.ceylonCode.resolve;

import com.intellij.psi.PsiElement;
import com.redhat.ceylon.compiler.typechecker.tree.Node;
import org.intellij.plugins.ceylon.ide.ceylonCode.psi.CeylonCompositeElement;
import org.intellij.plugins.ceylon.ide.ceylonCode.psi.CeylonPsiVisitor;
import org.jetbrains.annotations.Nullable;

public class FindMatchingPsiNodeVisitor extends CeylonPsiVisitor {

    private Node node;
    private Class<? extends CeylonCompositeElement> klass;
    private CeylonCompositeElement psi;

    public FindMatchingPsiNodeVisitor(Node node, Class<? extends CeylonCompositeElement> klass) {
        super(true);
        this.node = node;
        this.klass = klass;
    }

    @Override
    public void visitElement(PsiElement element) {
        super.visitElement(element);

        if (element.getTextRange().equalsToRange(node.getStartIndex(), node.getEndIndex())
                && klass.isAssignableFrom(element.getClass())) {
            psi = (CeylonCompositeElement) element;
        }
    }

    @Nullable
    public CeylonCompositeElement getPsi() {
        return psi;
    }
}
