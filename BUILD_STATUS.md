# Build status — 3105 2.1 beta 2

Esta Source foi adaptada para a IPA de referência `3105-2.1-beta2-no-key-ui-unsigned.ipa`.

## Identidade aplicada

- Nome exibido: `3105`
- Executável: `3105`
- Bundle ID: `com.apple.mobile.MobileHouseArrest`
- Marketing version: `2.1`
- Build: `2`
- Deployment target: iOS 16.0
- Arquiteturas: arm64

## Origem dos recursos

Os recursos, telas, autenticação e pacotes `.3105` vieram da Source enviada. A Source não é o código original exato do binário 2.1 beta 2; é uma variante personalizada do projeto 3105. O binário da IPA não permite recuperar mudanças que não estejam na Source.

## Codemagic

O workflow `ios-unsigned` gera `build/ipa/3105.ipa` sem assinatura, preservando o bundle e a versão acima. Para instalar em dispositivo, use os certificados/provisioning profiles da sua conta Apple em uma etapa de assinatura compatível. Nenhuma chave ou segredo foi incluído.

## Layout dos patches

As linhas de patch não renderizam ícone, checkbox ou quadrado lateral. O único controle visual à direita é o switch; o status permanece abaixo do nome.
