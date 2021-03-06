package org.intellij.plugins.ceylon.ide.annotator;

import com.intellij.psi.PsiFile;
import org.intellij.plugins.ceylon.ide.CeylonCodeInsightTestSupport;
import org.intellij.plugins.ceylon.ide.ceylonCode.psi.CeylonFile;

public class CeylonSyntaxAnnotatorTest extends CeylonCodeInsightTestSupport {

    @Override
    protected String getTestDataPath() {
        return "testdata/source";
    }

    public void testSyntaxAnnotator() throws Exception {
        testSyntax("SyntaxError", false, false, false);
    }

    private void testSyntax(String cuName, boolean checkWarnings, boolean checkInfos, boolean checkWeakWarnings) {

        PsiFile[] files = myFixture.configureByFiles("org/intellij/plugins/ceylon/annotator/" + cuName + ".ceylon");
        ((CeylonFile) files[0]).ensureTypechecked();

        myFixture.checkHighlighting(checkWarnings, checkInfos, checkWeakWarnings);
    }
}
