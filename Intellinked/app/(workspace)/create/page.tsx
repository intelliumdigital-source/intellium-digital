import { CreatePostStudio } from "@/app/_components/create-post-studio";
import { PageIntro } from "@/app/_components/ui";

export default function CreatePage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Create post"
        title="Compose a premium post flow without backend complexity."
        description="This MVP uses a full-page composer that behaves like a modal experience on top of the dark social workspace."
      />
      <CreatePostStudio />
    </div>
  );
}
