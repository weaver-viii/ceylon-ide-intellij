import com.intellij.navigation {
    NavigationItem,
    ItemPresentationProviders
}
import com.intellij.openapi.project {
    Project
}
import com.intellij.pom {
    Navigatable
}
import com.redhat.ceylon.ide.common.model {
    SourceFile
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

import org.intellij.plugins.ceylon.ide.ceylonCode.resolve {
    CeylonReference
}
import com.intellij.openapi.actionSystem {
    DataProvider,
    CommonDataKeys
}
import com.intellij.psi {
    PsiNameIdentifierOwner
}

shared class DeclarationNavigationItem(shared Declaration declaration, shared Project project)
        satisfies NavigationItem
                & DataProvider {

    canNavigate() => true;

    canNavigateToSource() => declaration.unit is SourceFile;

    name => declaration.name;

    shared actual void navigate(Boolean requestFocus) {
        if (exists resolved = CeylonReference.resolveDeclaration(declaration, project),
            is Navigatable resolved) {
            resolved.navigate(requestFocus);
        } else if (is SourceFile unit = declaration.unit) {
            // TODO open file
        }
    }

    presentation => ItemPresentationProviders.getItemPresentation(this);

    shared actual Boolean equals(Object that) {
        if (is DeclarationNavigationItem that) {
            return declaration ==that.declaration &&
                        project==that.project;
        }
        else {
            return false;
        }
    }

    shared actual Integer hash {
        variable value hash = 1;
        hash = 31*hash + declaration.hash;
        hash = 31*hash + project.hash;
        return hash;
    }

    shared actual Object? getData(String dataId) {
        if (dataId == CommonDataKeys.psiElement.name,
            exists psi = CeylonReference.resolveDeclaration(declaration, project)) {

            if (is PsiNameIdentifierOwner psi,
                exists id = psi.nameIdentifier) {

                return id;
            }
            return psi;
        }
        return null;
    }

}
